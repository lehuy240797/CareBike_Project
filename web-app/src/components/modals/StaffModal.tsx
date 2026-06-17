import React, { useState } from 'react';
import { AlertCircle, UserCog, Eye, EyeOff } from 'lucide-react';
import ModalOverlay from './ModalOverlay';
import LoadingSpinner from '../ui/LoadingSpinner';
import { apiCreateStaff } from '../../services/authService';
import type { CreateStaffRequest } from '../../services/authService';

interface StaffModalProps {
  onClose: () => void;
  onSuccess: () => void;
}

const StaffModal = ({ onClose, onSuccess }: StaffModalProps) => {
  const [form, setForm] = useState({ fullName: '', phone: '', email: '', password: '' });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [serverError, setServerError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setForm({ ...form, [e.target.name]: e.target.value });
    setErrors({ ...errors, [e.target.name]: '' });
    setServerError('');
  };

  const validate = () => {
    const e: Record<string, string> = {};
    if (!form.fullName.trim()) e.fullName = 'Họ tên không được để trống.';
    if (!form.phone.trim()) e.phone = 'Số điện thoại không được để trống.';
    if (!form.email.trim() || !/\S+@\S+\.\S+/.test(form.email)) e.email = 'Email không hợp lệ.';
    if (!form.password || form.password.length < 6) e.password = 'Mật khẩu tối thiểu 6 ký tự.';
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleSubmit = async (ev: React.FormEvent) => {
    ev.preventDefault();
    if (!validate()) return;
    setIsSubmitting(true);
    try {
      const payload: CreateStaffRequest = {
        fullName: form.fullName.trim(),
        userPhone: form.phone.trim(),
        email: form.email.trim(),
        password: form.password,
      };
      await apiCreateStaff(payload);
      onSuccess();
    } catch (err: any) {
      setServerError(err?.response?.data?.message ?? 'Lỗi khi tạo tài khoản.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <ModalOverlay title="Tạo tài khoản quản lý" onClose={onClose} contentClass="modal-content--sm">
      {serverError && (
        <div className="auth-alert auth-alert--error" style={{ marginBottom: '1rem', display: 'flex', gap: '8px' }}>
          <AlertCircle size={15} /> <span>{serverError}</span>
        </div>
      )}
      <form className="modal-form" onSubmit={handleSubmit} noValidate>
        <div className="modal-section-label">
          <UserCog size={14} /> Thông tin tài khoản
        </div>

        <div className="form-group">
          <label className="form-label">Họ và tên *</label>
          <input name="fullName" type="text" className={`auth-input${errors.fullName ? ' auth-input--error' : ''}`} value={form.fullName} onChange={handleChange} disabled={isSubmitting} placeholder="Nguyễn Văn An" />
          {errors.fullName && <span className="auth-field-error">{errors.fullName}</span>}
        </div>

        <div className="form-group">
          <label className="form-label">Số điện thoại *</label>
          <input name="phone" type="tel" className={`auth-input${errors.phone ? ' auth-input--error' : ''}`} value={form.phone} onChange={handleChange} disabled={isSubmitting} placeholder="0987654321" />
          {errors.phone && <span className="auth-field-error">{errors.phone}</span>}
        </div>

        <div className="form-group">
          <label className="form-label">Email đăng nhập *</label>
          <input name="email" type="email" className={`auth-input${errors.email ? ' auth-input--error' : ''}`} value={form.email} onChange={handleChange} disabled={isSubmitting} placeholder="branch@carebike.vn" />
          {errors.email && <span className="auth-field-error">{errors.email}</span>}
        </div>

        <div className="form-group">
          <label className="form-label">Mật khẩu *</label>
          <div className="auth-input-wrapper">
            <input name="password" type={showPassword ? 'text' : 'password'} className={`auth-input auth-input--with-icon${errors.password ? ' auth-input--error' : ''}`} value={form.password} onChange={handleChange} disabled={isSubmitting} placeholder="Tối thiểu 6 ký tự" />
            <button type="button" className="auth-input-icon-btn" onClick={() => setShowPassword(!showPassword)}>
              {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
            </button>
          </div>
          {errors.password && <span className="auth-field-error">{errors.password}</span>}
        </div>

        <div className="modal-footer">
          <button type="button" className="app-btn app-btn--outline" onClick={onClose} disabled={isSubmitting}>Hủy</button>
          <button type="submit" className="app-btn" disabled={isSubmitting}>
            {isSubmitting ? <><LoadingSpinner size={15} color="#fff" /> Đang tạo...</> : 'Tạo tài khoản'}
          </button>
        </div>
      </form>
    </ModalOverlay>
  );
};
export default StaffModal;