import React, { useState } from 'react';
import { Eye, EyeOff, CheckCircle, AlertCircle, ShieldCheck } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import LoadingSpinner from '../components/ui/LoadingSpinner';
import type { ChangePasswordRequest } from '../types/auth';

interface FormState extends ChangePasswordRequest {
  confirmNewPassword: string;
}

const INITIAL_FORM: FormState = {
  oldPassword: '',
  newPassword: '',
  confirmNewPassword: '',
};

const ChangePassword: React.FC = () => {
  const { changePassword } = useAuth();

  const [form, setForm] = useState<FormState>(INITIAL_FORM);
  const [showOld, setShowOld] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [errors, setErrors] = useState<Partial<FormState>>({});
  const [serverError, setServerError] = useState('');
  const [success, setSuccess] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value }));
    if (errors[name as keyof FormState]) {
      setErrors((prev) => ({ ...prev, [name]: undefined }));
    }
    if (serverError) setServerError('');
    if (success) setSuccess(false);
  };

  const validate = (): boolean => {
    const newErrors: Partial<FormState> = {};

    if (!form.oldPassword) {
      newErrors.oldPassword = 'Vui lòng nhập mật khẩu hiện tại.';
    }

    if (!form.newPassword) {
      newErrors.newPassword = 'Mật khẩu mới không được để trống.';
    } else if (form.newPassword.length < 6) {
      newErrors.newPassword = 'Mật khẩu mới tối thiểu 6 ký tự.';
    } else if (form.newPassword === form.oldPassword) {
      newErrors.newPassword = 'Mật khẩu mới phải khác mật khẩu hiện tại.';
    }

    if (!form.confirmNewPassword) {
      newErrors.confirmNewPassword = 'Vui lòng xác nhận mật khẩu mới.';
    } else if (form.newPassword !== form.confirmNewPassword) {
      newErrors.confirmNewPassword = 'Mật khẩu xác nhận không khớp.';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validate()) return;

    setIsSubmitting(true);
    setServerError('');

    try {
      await changePassword({
        oldPassword: form.oldPassword,
        newPassword: form.newPassword,
      });
      setSuccess(true);
      setForm(INITIAL_FORM);
    } catch (err: unknown) {
      if (err instanceof Error) {
        // Surface backend errors gracefully (e.g. wrong old password)
        setServerError(err.message);
      } else {
        setServerError('Đổi mật khẩu thất bại. Vui lòng thử lại.');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="dashboard-inner dashboard-inner--narrow">
      <div className="page-header">
        <ShieldCheck size={28} className="page-header-icon" aria-hidden="true" />
        <div>
          <h1 className="dashboard-title" style={{ margin: 0 }}>Đổi mật khẩu</h1>
          <p className="page-subtitle">Cập nhật mật khẩu đăng nhập của bạn</p>
        </div>
      </div>

      <div className="dashboard-panel change-password-panel">
        {/* Success banner */}
        {success && (
          <div className="auth-alert auth-alert--success" role="status" style={{ display: 'flex', gap: '0.5rem', alignItems: 'flex-start' }}>
            <CheckCircle size={16} aria-hidden="true" style={{ flexShrink: 0, marginTop: '1px' }} />
            <span>Mật khẩu đã được cập nhật thành công!</span>
          </div>
        )}

        {/* Server error banner */}
        {serverError && (
          <div className="auth-alert auth-alert--error" role="alert" style={{ display: 'flex', gap: '0.5rem', alignItems: 'flex-start' }}>
            <AlertCircle size={16} aria-hidden="true" style={{ flexShrink: 0, marginTop: '1px' }} />
            <span>{serverError}</span>
          </div>
        )}

        <form className="auth-form" onSubmit={handleSubmit} noValidate>
          {/* Current password */}
          <div className="auth-field">
            <label className="auth-label" htmlFor="oldPassword">Mật khẩu hiện tại</label>
            <div className="auth-input-wrapper">
              <input
                id="oldPassword"
                name="oldPassword"
                type={showOld ? 'text' : 'password'}
                className={`auth-input auth-input--with-icon${errors.oldPassword ? ' auth-input--error' : ''}`}
                placeholder="Nhập mật khẩu hiện tại..."
                autoComplete="current-password"
                value={form.oldPassword}
                onChange={handleChange}
                disabled={isSubmitting}
                aria-invalid={!!errors.oldPassword}
                aria-describedby={errors.oldPassword ? 'oldPassword-error' : undefined}
              />
              <button
                type="button"
                className="auth-input-icon-btn"
                onClick={() => setShowOld((v) => !v)}
                aria-label={showOld ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
                tabIndex={-1}
              >
                {showOld ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            {errors.oldPassword && (
              <span id="oldPassword-error" className="auth-field-error" role="alert">{errors.oldPassword}</span>
            )}
          </div>

          {/* New password row */}
          <div className="auth-row">
            <div className="auth-field">
              <label className="auth-label" htmlFor="newPassword">Mật khẩu mới</label>
              <div className="auth-input-wrapper">
                <input
                  id="newPassword"
                  name="newPassword"
                  type={showNew ? 'text' : 'password'}
                  className={`auth-input auth-input--with-icon${errors.newPassword ? ' auth-input--error' : ''}`}
                  placeholder="Tối thiểu 6 ký tự"
                  autoComplete="new-password"
                  value={form.newPassword}
                  onChange={handleChange}
                  disabled={isSubmitting}
                  aria-invalid={!!errors.newPassword}
                  aria-describedby={errors.newPassword ? 'newPassword-error' : undefined}
                />
                <button
                  type="button"
                  className="auth-input-icon-btn"
                  onClick={() => setShowNew((v) => !v)}
                  aria-label={showNew ? 'Ẩn mật khẩu mới' : 'Hiện mật khẩu mới'}
                  tabIndex={-1}
                >
                  {showNew ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              {errors.newPassword && (
                <span id="newPassword-error" className="auth-field-error" role="alert">{errors.newPassword}</span>
              )}
            </div>

            <div className="auth-field">
              <label className="auth-label" htmlFor="confirmNewPassword">Xác nhận mật khẩu mới</label>
              <div className="auth-input-wrapper">
                <input
                  id="confirmNewPassword"
                  name="confirmNewPassword"
                  type={showConfirm ? 'text' : 'password'}
                  className={`auth-input auth-input--with-icon${errors.confirmNewPassword ? ' auth-input--error' : ''}`}
                  placeholder="Nhập lại mật khẩu mới"
                  autoComplete="new-password"
                  value={form.confirmNewPassword}
                  onChange={handleChange}
                  disabled={isSubmitting}
                  aria-invalid={!!errors.confirmNewPassword}
                  aria-describedby={errors.confirmNewPassword ? 'confirmNewPassword-error' : undefined}
                />
                <button
                  type="button"
                  className="auth-input-icon-btn"
                  onClick={() => setShowConfirm((v) => !v)}
                  aria-label={showConfirm ? 'Ẩn mật khẩu xác nhận' : 'Hiện mật khẩu xác nhận'}
                  tabIndex={-1}
                >
                  {showConfirm ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              {errors.confirmNewPassword && (
                <span id="confirmNewPassword-error" className="auth-field-error" role="alert">{errors.confirmNewPassword}</span>
              )}
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <button
              type="submit"
              className="auth-btn"
              style={{ width: 'auto', minWidth: '12rem' }}
              disabled={isSubmitting}
              aria-busy={isSubmitting}
            >
              {isSubmitting ? (
                <>
                  <LoadingSpinner size={17} color="#fff" />
                  Đang lưu...
                </>
              ) : (
                'Cập nhật mật khẩu'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ChangePassword;