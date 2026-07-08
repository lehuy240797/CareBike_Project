import React, { useState } from 'react';
import { Eye, EyeOff, CheckCircle, AlertCircle, ShieldCheck, Lock, Check } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import LoadingSpinner from '../components/ui/LoadingSpinner';
import { btnPrimary, dashTitle, eyebrow, fieldError, inputBase, label } from '../ui/styles';
import type { ChangePasswordRequest } from '../types/auth';

const eyeBtn =
  'absolute right-3 top-1/2 flex -translate-y-1/2 items-center justify-center border-none bg-transparent p-1 text-ink-muted transition-colors hover:text-ink';

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
      newErrors.oldPassword = 'Please enter your current password.';
    }

    if (!form.newPassword) {
      newErrors.newPassword = 'New password cannot be empty.';
    } else if (form.newPassword.length < 6) {
      newErrors.newPassword = 'New password must be at least 6 characters.';
    } else if (form.newPassword === form.oldPassword) {
      newErrors.newPassword = 'New password must differ from the current one.';
    }

    if (!form.confirmNewPassword) {
      newErrors.confirmNewPassword = 'Please confirm the new password.';
    } else if (form.newPassword !== form.confirmNewPassword) {
      newErrors.confirmNewPassword = 'Password confirmation does not match.';
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
        setServerError('Failed to change password. Please try again.');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  // Live requirement hints (presentational — derived from form state)
  const reqs = [
    { label: 'At least 6 characters', ok: form.newPassword.length >= 6 },
    {
      label: 'Different from current password',
      ok: form.newPassword.length > 0 && form.newPassword !== form.oldPassword,
    },
    {
      label: 'Matches confirmation',
      ok: form.confirmNewPassword.length > 0 && form.newPassword === form.confirmNewPassword,
    },
  ];

  // Inline render helper (NOT a component — avoids input remount / focus loss)
  const passwordField = (
    id: string,
    name: keyof FormState,
    labelText: string,
    placeholder: string,
    show: boolean,
    toggle: () => void,
    autoComplete: string,
  ) => (
    <div className="flex flex-col gap-1.5">
      <label className={label} htmlFor={id}>{labelText}</label>
      <div className="relative">
        <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted" aria-hidden="true" />
        <input
          id={id}
          name={name}
          type={show ? 'text' : 'password'}
          className={`${inputBase} pl-10 pr-11${errors[name] ? ' !border-red-300' : ''}`}
          placeholder={placeholder}
          autoComplete={autoComplete}
          value={form[name]}
          onChange={handleChange}
          disabled={isSubmitting}
          aria-invalid={!!errors[name]}
          aria-describedby={errors[name] ? `${id}-error` : undefined}
        />
        <button
          type="button"
          className={eyeBtn}
          onClick={toggle}
          aria-label={show ? 'Hide password' : 'Show password'}
          tabIndex={-1}
        >
          {show ? <EyeOff size={16} /> : <Eye size={16} />}
        </button>
      </div>
      {errors[name] && (
        <span id={`${id}-error`} className={fieldError} role="alert">{errors[name]}</span>
      )}
    </div>
  );

  return (
    <div className="mx-auto max-w-[64rem]">
      {/* Header */}
      <div className="mb-8 animate-fade-up">
        <p className={eyebrow}>Security</p>
        <h1 className={`${dashTitle} mt-1`}>Change Password</h1>
        <p className="mt-1.5 font-pop text-sm text-ink-muted">Update your login password</p>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-5">
        {/* Security info + live checklist */}
        <div className="order-2 lg:col-span-2">
          <div className="rounded-3xl border border-edge bg-white p-6 shadow-sm lg:sticky lg:top-6">
            <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-white shadow-[0_0_20px_rgba(249,115,22,0.35)]">
              <ShieldCheck size={26} aria-hidden="true" />
            </div>
            <h3 className="m-0 font-display text-xl font-black text-ink">Account security</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">
              Choose a strong, unique password to protect your admin account.
            </p>

            <div className="mt-6 space-y-3">
              {reqs.map((r) => (
                <div key={r.label} className="flex items-center gap-2.5">
                  <span
                    className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full transition-colors ${r.ok ? 'bg-green-100 text-green-600' : 'bg-primary-light text-ink-muted'
                      }`}
                  >
                    {r.ok ? <Check size={14} /> : <span className="h-1.5 w-1.5 rounded-full bg-current" />}
                  </span>
                  <span className={`text-sm transition-colors ${r.ok ? 'font-semibold text-ink' : 'text-ink-muted'}`}>
                    {r.label}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Form */}
        <div className="order-1 lg:col-span-3">
          <div className="rounded-3xl border border-edge bg-white p-6 shadow-sm sm:p-8">
            {/* Success banner */}
            {success && (
              <div className="mb-5 flex items-start gap-2 rounded-2xl border border-green-200 bg-green-50 px-4 py-3 text-sm leading-normal text-green-700" role="status">
                <CheckCircle size={16} aria-hidden="true" className="mt-px shrink-0" />
                <span>Your password was updated successfully!</span>
              </div>
            )}

            {/* Server error banner */}
            {serverError && (
              <div className="mb-5 flex items-start gap-2 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-normal text-red-600" role="alert">
                <AlertCircle size={16} aria-hidden="true" className="mt-px shrink-0" />
                <span>{serverError}</span>
              </div>
            )}

            <form className="flex flex-col gap-5" onSubmit={handleSubmit} noValidate>
              {passwordField('oldPassword', 'oldPassword', 'Current password', 'Enter your current password...', showOld, () => setShowOld((v) => !v), 'current-password')}

              <div className="h-px bg-edge" />

              {passwordField('newPassword', 'newPassword', 'New password', 'At least 6 characters', showNew, () => setShowNew((v) => !v), 'new-password')}
              {passwordField('confirmNewPassword', 'confirmNewPassword', 'Confirm new password', 'Re-enter the new password', showConfirm, () => setShowConfirm((v) => !v), 'new-password')}

              <button
                type="submit"
                className={`${btnPrimary} mt-1 w-full px-5 py-3 text-[0.9375rem]`}
                disabled={isSubmitting}
                aria-busy={isSubmitting}
              >
                {isSubmitting ? (
                  <>
                    <LoadingSpinner size={17} color="#fff" />
                    Saving...
                  </>
                ) : (
                  'Update password'
                )}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ChangePassword;
