/**
 * AuthContext.tsx
 * ───────────────
 * Single source of truth for authentication state using Firebase Auth.
 *
 * Token strategy:
 * • Firebase quản lý phiên đăng nhập và tự động refresh token.
 * • AccessToken → Firebase Token được lấy ra và gán vào apiClient in-memory.
 * • User info   → localStorage('authUser') để hiển thị giao diện tức thời.
 *
 * BUSINESS RULE: Customer accounts may NOT log in on the web app.
 * If a customer authenticates successfully, we immediately log them out from Firebase
 * and throw a descriptive error for the Login page to display.
 */

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import { useNavigate } from 'react-router-dom';
import { getAuth, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { setAccessToken } from '../services/apiClient';
import { apiLogin, apiGetMe } from '../services/authService';
import type {
  AuthUser,
  LoginRequest,
  RegisterRequest,
  ChangePasswordRequest,
  UserRole,
} from '../types/auth';

// ─── Context shape ─────────────────────────────────────────────────────────────

interface AuthContextValue {
  user: AuthUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (credentials: LoginRequest) => Promise<void>;
  // Các hàm cũ giữ lại signature để không báo lỗi ở component khác
  register: (data: RegisterRequest) => Promise<void>;
  changePassword: (data: ChangePasswordRequest) => Promise<void>;
  logout: () => Promise<void>;
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

const USER_STORAGE_KEY = 'authUser';

function persistUser(user: AuthUser): void {
  localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(user));
}

function clearPersistedAuth(): void {
  localStorage.removeItem(USER_STORAGE_KEY);
}

function readPersistedUser(): AuthUser | null {
  try {
    const raw = localStorage.getItem(USER_STORAGE_KEY);
    return raw ? (JSON.parse(raw) as AuthUser) : null;
  } catch {
    return null;
  }
}

// ─── Context ───────────────────────────────────────────────────────────────────

const AuthContext = createContext<AuthContextValue>(null!);

// ─── Provider ─────────────────────────────────────────────────────────────────

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  const navigate = useNavigate();
  const navigateRef = useRef(navigate);
  useEffect(() => {
    navigateRef.current = navigate;
  }, [navigate]);

  // ── Logout ──────────────────────────────────────────────────────────────────
  const logout = useCallback(async () => {
    try {
      const auth = getAuth();
      await signOut(auth); // Đăng xuất khỏi Firebase
    } catch (error) {
      console.error('Lỗi khi đăng xuất Firebase:', error);
    } finally {
      setAccessToken(null);
      clearPersistedAuth();
      setUser(null);
      setIsAuthenticated(false);
      navigateRef.current('/login', { replace: true });
    }
  }, []);

  // ── Listen for silent logout events fired by the apiClient interceptor ───────
  useEffect(() => {
    const handler = () => void logout();
    window.addEventListener('auth:logout', handler);
    return () => window.removeEventListener('auth:logout', handler);
  }, [logout]);

  // ── Session rehydration on mount (F5 Refresh) ────────────────────────────────
  useEffect(() => {
    const rehydrate = async () => {
      const auth = getAuth();
      
      // Đợi Firebase khởi tạo trạng thái từ Local Storage của trình duyệt
      await auth.authStateReady();
      const firebaseUser = auth.currentUser;

      if (!firebaseUser) {
        clearPersistedAuth();
        setIsLoading(false);
        return;
      }

      try {
        // Lấy token mới nhất từ Firebase
        const token = await firebaseUser.getIdToken();
        setAccessToken(token);

        // Gọi API lấy thông tin mới nhất từ Backend (bao gồm Role)
        const backendData = await apiGetMe(token);

        // ──── XỬ LÝ NGHIỆP VỤ: Ngăn chặn tài khoản Customer truy cập Web Admin ────────────
        if (backendData.role === 'CUSTOMER') {
          await signOut(auth);
          throw new Error('Unauthorized');
        }

        let branchId: number | undefined = undefined;
        let storedUser = readPersistedUser();

        // Fetch branchId if role is BRANCH
        if (backendData.role === 'BRANCH') {
          if (storedUser?.branchId) {
            branchId = storedUser.branchId;
          } else {
            const { default: apiClient } = await import('../services/apiClient');
            const res = await apiClient.get('/branches');
            const branches = res.data;
            const myBranch = branches.find((b: any) => b.manager && b.manager.id === backendData.userId);
            if (myBranch) branchId = myBranch.id;
          }
        }

        const authUser: AuthUser = {
          userId: backendData.userId,
          username: backendData.email, // Map email từ backend sang username cho frontend
          role: backendData.role as UserRole,
          branchId,
        };

        persistUser(authUser);
        setUser(authUser);
        setIsAuthenticated(true);
      } catch (error) {
        console.error('Rehydration failed:', error);
        clearPersistedAuth();
        setAccessToken(null);
      } finally {
        setIsLoading(false);
      }
    };

    rehydrate();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

 // ── Login ────────────────────────────────────────────────────────────────────
  const login = useCallback(async (credentials: LoginRequest) => {
    const auth = getAuth();
    
    try {
      // 1. Xác thực bằng Firebase
      const userCredential = await signInWithEmailAndPassword(
        auth, 
        credentials.username, 
        credentials.password
      );

      // 2. Lấy Firebase Token
      const token = await userCredential.user.getIdToken();

      // 3. Đồng bộ Token với Backend. 
      // Phân quyền phía máy chủ sẽ tự động từ chối nếu người dùng là Customer.
      const response = await apiLogin(token);

      // (Đoạn if check CUSTOMER cũ ở đây đã được xóa bỏ vì Spring Boot đã lo việc đó)

      // 4. Nếu hợp lệ, gán token vào memory để gọi các API khác
      setAccessToken(token);

      let branchId: number | undefined = undefined;

      // 5. Fetch branchId if role is BRANCH
      if (response.role === 'BRANCH') {
        const { default: apiClient } = await import('../services/apiClient');
        const res = await apiClient.get('/branches');
        const branches = res.data;
        const myBranch = branches.find((b: any) => b.manager && b.manager.id === response.userId);
        if (myBranch) {
          branchId = myBranch.id;
        }
      }

      // 6. Lưu thông tin User
      const authUser: AuthUser = {
        userId: response.userId,
        username: response.email,
        role: response.role as UserRole,
        branchId,
      };
      
      persistUser(authUser);
      setUser(authUser);
      setIsAuthenticated(true);

    } catch (error: any) {
      // ====================================================================
      // XỬ LÝ NGOẠI LỆ: Xóa phiên đăng nhập lỗi và phiên dịch mã lỗi
      // ====================================================================
      
      // Dọn dẹp session Firebase ngay lập tức nếu Backend từ chối
      if (auth.currentUser) {
        await signOut(auth);
      }

      // 1. Lỗi từ Spring Boot (Axios Error: Lỗi 403 phân quyền, khóa tài khoản...)
      if (error.response && error.response.data && error.response.data.message) {
        throw new Error(error.response.data.message); // Hiển thị nguyên trạng thông báo lỗi từ phía Spring Boot
      }

      // 2. Lỗi từ Firebase (Sai pass, block, mất mạng...)
      if (error.code) {
        switch (error.code) {
          case 'auth/invalid-credential':
          case 'auth/wrong-password':
          case 'auth/user-not-found':
            throw new Error("Tên đăng nhập hoặc mật khẩu không chính xác.");
          case 'auth/too-many-requests':
            throw new Error("Tài khoản tạm khóa do nhập sai nhiều lần. Vui lòng thử lại sau.");
          case 'auth/user-disabled':
            throw new Error("Tài khoản của bạn đã bị vô hiệu hóa.");
          case 'auth/network-request-failed':
            throw new Error("Không có kết nối mạng. Vui lòng kiểm tra lại.");
          default:
            throw new Error("Hệ thống xác thực đang bận. Vui lòng thử lại sau.");
        }
      }

      // 3. Lỗi mạng chung hoặc server sập
      throw new Error("Không thể kết nối đến máy chủ. Vui lòng thử lại sau.");
    }
  }, []);

  // ── Register (Tạm thời giữ nguyên hoặc cấu hình sau) ────────────────────────
  const register = useCallback(async (_data: RegisterRequest) => {
    throw new Error('Tính năng đăng ký Web đang được cập nhật qua Firebase.');
  }, []);

  // ── Change Password (Tạm thời giữ nguyên hoặc cấu hình sau) ────────────────
  const changePassword = useCallback(async (_data: ChangePasswordRequest) => {
    throw new Error('Tính năng đổi mật khẩu đang được cập nhật qua Firebase.');
  }, []);

  return (
    <AuthContext.Provider
      value={{ user, isAuthenticated, isLoading, login, register, changePassword, logout }}
    >
      {children}
    </AuthContext.Provider>
  );
};

// ─── Hook ──────────────────────────────────────────────────────────────────────

export const useAuth = (): AuthContextValue => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
};