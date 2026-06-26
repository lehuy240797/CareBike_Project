import React, { useState } from 'react';
import { AlertCircle, UserCog, Eye, EyeOff } from 'lucide-react';
import ModalOverlay from './ModalOverlay';
import LoadingSpinner from '../ui/LoadingSpinner';
import { apiCreateStaff } from '../../services/authService';
import type { CreateStaffRequest } from '../../services/authService';
import { btnOutline, btnPrimary, fieldError, formGroup, inputBase, label, modalFooter, modalForm } from '../../ui/styles';

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
    if (!form.fullName.trim()) e.fullName = 'Full name is required.';
    if (!form.phone.trim()) e.phone = 'Phone number is required.';
    if (!form.email.trim() || !/\S+@\S+\.\S+/.test(form.email)) e.email = 'Invalid email.';
    if (!form.password || form.password.length < 6) e.password = 'Password must be at least 6 characters.';
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
      setServerError(err?.response?.data?.message ?? 'Error creating account.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <ModalOverlay title="Create manager account" onClose={onClose} contentClass="max-w-[400px]">
      {serverError && (
        <div className="mb-4 flex items-start gap-2 rounded-[10px] border border-red-200 bg-red-50 px-4 py-3 text-sm leading-normal text-red-600">
          <AlertCircle size={15} className="mt-px shrink-0" /> <span>{serverError}</span>
        </div>
      )}
      <form className={modalForm} onSubmit={handleSubmit} noValidate>
        <div className="flex items-center gap-2 text-[0.8125rem] font-bold uppercase tracking-[0.06em] text-ink-muted">
          <UserCog size={14} /> Account information
        </div>

        <div className={formGroup}>
          <label className={label}>Full name *</label>
          <input name="fullName" type="text" className={`${inputBase}${errors.fullName ? ' !border-red-300' : ''}`} value={form.fullName} onChange={handleChange} disabled={isSubmitting} placeholder="John Doe" />
          {errors.fullName && <span className={fieldError}>{errors.fullName}</span>}
        </div>

        <div className={formGroup}>
          <label className={label}>Phone number *</label>
          <input name="phone" type="tel" className={`${inputBase}${errors.phone ? ' !border-red-300' : ''}`} value={form.phone} onChange={handleChange} disabled={isSubmitting} placeholder="0987654321" />
          {errors.phone && <span className={fieldError}>{errors.phone}</span>}
        </div>

        <div className={formGroup}>
          <label className={label}>Login email *</label>
          <input name="email" type="email" className={`${inputBase}${errors.email ? ' !border-red-300' : ''}`} value={form.email} onChange={handleChange} disabled={isSubmitting} placeholder="branch@carebike.vn" />
          {errors.email && <span className={fieldError}>{errors.email}</span>}
        </div>

        <div className={formGroup}>
          <label className={label}>Password *</label>
          <div className="relative">
            <input name="password" type={showPassword ? 'text' : 'password'} className={`${inputBase} pr-11${errors.password ? ' !border-red-300' : ''}`} value={form.password} onChange={handleChange} disabled={isSubmitting} placeholder="At least 6 characters" />
            <button type="button" className="absolute right-3 top-1/2 flex -translate-y-1/2 items-center justify-center border-none bg-transparent p-1 text-ink-muted transition-colors hover:text-ink" onClick={() => setShowPassword(!showPassword)}>
              {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
            </button>
          </div>
          {errors.password && <span className={fieldError}>{errors.password}</span>}
        </div>

        <div className={modalFooter}>
          <button type="button" className={btnOutline} onClick={onClose} disabled={isSubmitting}>Cancel</button>
          <button type="submit" className={btnPrimary} disabled={isSubmitting}>
            {isSubmitting ? <><LoadingSpinner size={15} color="#fff" /> Creating...</> : 'Create account'}
          </button>
        </div>
      </form>
    </ModalOverlay>
  );
};
export default StaffModal;