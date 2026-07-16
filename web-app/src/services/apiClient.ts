import axios from 'axios';
import type { AxiosError, InternalAxiosRequestConfig } from 'axios';
import type { TokenRefreshRequest, TokenRefreshResponse } from '../types/auth';

// ─── Base URL ─────────────────────────────────────────────────────────────────

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080/api';

// ─── In-memory access token ───────────────────────────────────────────────────
// Keeping the access token in module scope (not localStorage) prevents XSS
// from reading it. AuthContext calls setAccessToken() after login / refresh.

let _accessToken: string | null = null;

export function setAccessToken(token: string | null): void {
  _accessToken = token;
}

export function getAccessToken(): string | null {
  return _accessToken;
}

// ─── Axios instance ───────────────────────────────────────────────────────────

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: { 'Content-Type': 'application/json; charset=UTF-8', Accept: 'application/json' },
});

// ─── Request interceptor ──────────────────────────────────────────────────────
// Attach the in-memory access token to every outgoing request.

apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    if (_accessToken) {
      config.headers.Authorization = `Bearer ${_accessToken}`;
    }
    return config;
  },
  (error: AxiosError) => Promise.reject(error),
);

// ─── Response interceptor — 401 token refresh ─────────────────────────────────
// When the server returns 401 (access token expired):
//   1. Pause all new requests.
//   2. Call /api/auth/refresh once with the stored refresh token.
//   3. Update the in-memory access token.
//   4. Replay all queued requests with the new token.

interface PendingRequest {
  resolve: (value: unknown) => void;
  reject: (reason: unknown) => void;
}

let isRefreshing = false;
let pendingQueue: PendingRequest[] = [];

function flushQueue(error: unknown, token: string | null = null): void {
  pendingQueue.forEach(({ resolve, reject }) => {
    if (error) {
      reject(error);
    } else {
      resolve(token);
    }
  });
  pendingQueue = [];
}

// Extend the config type to allow our custom _retry flag
interface RetryableConfig extends InternalAxiosRequestConfig {
  _retry?: boolean;
}

apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as RetryableConfig | undefined;

    // Only attempt refresh for 401 errors on non-refresh endpoints
    if (
      error.response?.status !== 401 ||
      !originalRequest ||
      originalRequest._retry ||
      originalRequest.url?.includes('/auth/refresh') ||
      originalRequest.url?.includes('/auth/login')
    ) {
      return Promise.reject(error);
    }

    if (isRefreshing) {
      // Queue this request until the refresh completes
      return new Promise((resolve, reject) => {
        pendingQueue.push({
          resolve: (token) => {
            if (originalRequest.headers) {
              originalRequest.headers.Authorization = `Bearer ${token}`;
            }
            resolve(apiClient(originalRequest));
          },
          reject,
        });
      });
    }

    originalRequest._retry = true;
    isRefreshing = true;

    const storedRefreshToken = localStorage.getItem('refreshToken');
    if (!storedRefreshToken) {
      isRefreshing = false;
      flushQueue(error);
      // Signal logout by dispatching a custom event
      window.dispatchEvent(new Event('auth:logout'));
      return Promise.reject(error);
    }

    try {
      // Use a plain axios call (not our instance) to avoid interceptor loops
      const { data } = await axios.post<TokenRefreshResponse>(
        `${API_BASE_URL}/auth/refresh`,
        { refreshToken: storedRefreshToken } satisfies TokenRefreshRequest,
      );

      // Persist new tokens
      setAccessToken(data.accessToken);
      localStorage.setItem('refreshToken', data.refreshToken);

      // Retry queued requests
      flushQueue(null, data.accessToken);

      // Replay the original request
      if (originalRequest.headers) {
        originalRequest.headers.Authorization = `Bearer ${data.accessToken}`;
      }
      return apiClient(originalRequest);
    } catch (refreshError) {
      flushQueue(refreshError);
      setAccessToken(null);
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('authUser');
      window.dispatchEvent(new Event('auth:logout'));
      return Promise.reject(refreshError);
    } finally {
      isRefreshing = false;
    }
  },
);

export default apiClient;
