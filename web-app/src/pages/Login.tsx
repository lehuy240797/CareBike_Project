import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Eye, EyeOff, AlertCircle } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { AuthLayout } from '../components/auth/AuthLayout';
import LoadingSpinner from '../components/ui/LoadingSpinner';
import type { LoginRequest } from '../types/auth';

const Login: React.FC = () => {
  const { login, isAuthenticated, isLoading: authLoading } = useAuth();
  const navigate = useNavigate();

  const [form, setForm] = useState<LoginRequest>({ username: '', password: '' });
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Tự động chuyển hướng nếu người dùng đã đăng nhập từ trước
  useEffect(() => {
    if (!authLoading && isAuthenticated) {
      navigate('/', { replace: true });
    }
  }, [isAuthenticated, authLoading, navigate]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
    // Tự động ẩn thông báo lỗi khi người dùng bắt đầu gõ lại
    if (error) setError('');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.username.trim() || !form.password.trim()) {
      setError('Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.');
      return;
    }

    setError('');
    setIsSubmitting(true);
    
    try {
      await login(form);
      navigate('/', { replace: true });
    } catch (err: any) {
      // =========================================================================
      // XỬ LÝ LỖI: Tiếp nhận lỗi từ AuthContext và phản hồi lên giao diện
      // =========================================================================
      if (err instanceof Error) {
        setError(err.message);
      } else if (err?.message) {
        setError(err.message);
      } else {
        setError('Hệ thống đang bận hoặc mất kết nối. Vui lòng thử lại sau.');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AuthLayout>
      <div className="auth-card">
        <h2 className="auth-card-title">Đăng nhập</h2>
        <p className="auth-card-subtitle">
          Chào mừng trở lại — dành cho Quản trị viên &amp; Chi nhánh
        </p>

        {/* Khu vực hiển thị thông báo lỗi */}
        {error && (
          <div className="auth-alert auth-alert--error" role="alert">
            <AlertCircle size={16} aria-hidden="true" style={{ flexShrink: 0, marginTop: '1px' }} />
            <span>{error}</span>
          </div>
        )}

        <form className="auth-form" onSubmit={handleSubmit} noValidate>
          {/* Username */}
          <div className="auth-field">
            <label className="auth-label" htmlFor="username">
              Tên đăng nhập
            </label>
            <input
              id="username"
              name="username"
              type="text"
              className="auth-input"
              placeholder="Nhập email hoặc tên đăng nhập..."
              autoComplete="username"
              autoFocus
              value={form.username}
              onChange={handleChange}
              disabled={isSubmitting}
              aria-invalid={!!error}
              required
            />
          </div>

          {/* Password */}
          <div className="auth-field">
            <label className="auth-label" htmlFor="password">
              Mật khẩu
            </label>
            <div className="auth-input-wrapper">
              <input
                id="password"
                name="password"
                type={showPassword ? 'text' : 'password'}
                className="auth-input auth-input--with-icon"
                placeholder="Nhập mật khẩu..."
                autoComplete="current-password"
                value={form.password}
                onChange={handleChange}
                disabled={isSubmitting}
                aria-invalid={!!error}
                required
              />
              <button
                type="button"
                className="auth-input-icon-btn"
                onClick={() => setShowPassword((v) => !v)}
                aria-label={showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
                tabIndex={-1}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            className="auth-btn"
            disabled={isSubmitting}
            aria-busy={isSubmitting}
          >
            {isSubmitting ? (
              <>
                <LoadingSpinner size={17} color="#fff" />
                <span>Đang đăng nhập...</span>
              </>
            ) : (
              'Đăng nhập'
            )}
          </button>
        </form>
      </div>
    </AuthLayout>
  );
};

export default Login;