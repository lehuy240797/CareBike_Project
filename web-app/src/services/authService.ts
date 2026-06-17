import apiClient from './apiClient';

// Định nghĩa kiểu dữ liệu trả về từ Backend (dựa theo AuthController mới)
export interface LoginResponse {
  userId: number;
  email: string;
  fullName: string;
  role: string;
  message?: string;
}

/** * POST /api/auth/login 
 * Gửi Firebase Token lên Backend để xác thực và lấy thông tin User (gồm Role).
 * Truyền trực tiếp token vào header để tránh trường hợp interceptor của apiClient chưa kịp update.
 */
export const apiLogin = (firebaseToken: string): Promise<LoginResponse> =>
  apiClient.post<LoginResponse>('/auth/login', {}, {
    headers: {
      Authorization: `Bearer ${firebaseToken}`
    }
  }).then((res) => res.data);

/** * GET /api/auth/me
 * Lấy thông tin user hiện tại (thường dùng khi F5 refresh trang web).
 */
export const apiGetMe = (firebaseToken: string): Promise<LoginResponse> =>
  apiClient.get<LoginResponse>('/auth/me', {
    headers: {
      Authorization: `Bearer ${firebaseToken}`
    }
  }).then((res) => res.data);

/// Tạo tài khoản nhân viên mới (chỉ dành cho ADMIN)
export interface CreateStaffRequest {
  email: string;
  password?: string;
  fullName: string;
  userPhone: string;
}

/// POST /api/auth/create-staff
export const apiCreateStaff = (data: CreateStaffRequest): Promise<{ message: string, userId: number }> =>
  apiClient.post('/auth/create-staff', data).then((res) => res.data);