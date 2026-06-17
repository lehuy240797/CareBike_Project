// ─── Roles ────────────────────────────────────────────────────────────────────

export type UserRole = 'ADMIN' | 'BRANCH' | 'CUSTOMER';

// ─── Domain model ─────────────────────────────────────────────────────────────

/** Lightweight user stored in AuthContext (derived from JWT + login response). */
export interface AuthUser {
  userId: number;
  username: string;
  role: UserRole;
  branchId?: number; // Fetched and populated if user is BRANCH
}

// ─── API Request bodies ────────────────────────────────────────────────────────

export interface LoginRequest {
  username: string;
  password: string;
}

export interface RegisterRequest {
  username: string;
  password: string;
  email: string;
  fullName: string;
  phone: string;
}

export interface ChangePasswordRequest {
  oldPassword: string;
  newPassword: string;
}

export interface TokenRefreshRequest {
  refreshToken: string;
}

// ─── API Response shapes ───────────────────────────────────────────────────────

/** Returned by POST /api/auth/login */
export interface JwtResponse {
  accessToken: string;
  refreshToken: string;
  userId: number;
  username: string;
  role: UserRole;
}

/** Returned by POST /api/auth/refresh */
export interface TokenRefreshResponse {
  accessToken: string;
  refreshToken: string;
}

/** Generic backend error response shape */
export interface ApiErrorResponse {
  message?: string;
  error?: string;
  status?: number;
}