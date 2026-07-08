import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Eye, EyeOff, AlertCircle, User, Lock, Shield,
  BarChart2, Store, Asterisk, ArrowRight,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import LoadingSpinner from '../components/ui/LoadingSpinner';
import type { LoginRequest } from '../types/auth';

const FEATURES = [
  { icon: Store, text: 'Manage branches & managers' },
  { icon: BarChart2, text: 'Real-time service analytics' },
  { icon: Asterisk, text: 'Coordinate emergency rescues' },
];

const Login: React.FC = () => {
  const { login, isAuthenticated, isLoading: authLoading } = useAuth();
  const navigate = useNavigate();

  const [form, setForm] = useState<LoginRequest>({ username: '', password: '' });
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (!authLoading && isAuthenticated) navigate('/', { replace: true });
  }, [isAuthenticated, authLoading, navigate]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
    if (error) setError('');
  };

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!form.username.trim() || !form.password.trim()) {
      setError('Please enter both your username and password.');
      return;
    }
    setError('');
    setIsSubmitting(true);
    try {
      await login(form);
      navigate('/', { replace: true });
    } catch (err: any) {
      if (err instanceof Error) setError(err.message);
      else if (err?.message) setError(err.message);
      else setError('The system is busy or the connection was lost. Please try again later.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="flex min-h-screen">

      {/* ── Left branding panel ───────────────────────────────────── */}
      <div
        className="hidden lg:flex lg:w-105 xl:w-125 shrink-0 flex-col relative overflow-hidden"
        style={{ background: 'linear-gradient(160deg,#f9923a 0%,#f97316 45%,#fb8a20 100%)' }}
      >
        {/* Large filled circle — top right */}
        <div
          className="pointer-events-none absolute rounded-full"
          style={{
            width: '340px', height: '340px',
            top: '-90px', right: '-90px',
            background: 'rgba(255,160,60,0.45)',
          }}
        />
        {/* Large filled circle — bottom right */}
        <div
          className="pointer-events-none absolute rounded-full"
          style={{
            width: '300px', height: '300px',
            bottom: '-80px', right: '-70px',
            background: 'rgba(255,160,60,0.38)',
          }}
        />
        {/* Small accent dots */}
        <div className="pointer-events-none absolute top-[38%] left-[14%] h-2 w-2 rounded-full bg-white/50" />
        <div className="pointer-events-none absolute top-[22%] right-[18%] h-1.5 w-1.5 rounded-full bg-white/60" />

        <div className="relative z-10 flex h-full flex-col justify-center px-10 py-14">
          {/* Logo */}
          <div className="mb-12">
            <h1 className="mb-2 text-[3.2rem] font-black italic leading-none tracking-tight">
              <span className="text-white">CARE</span>
              <span style={{ color: '#1c0800' }}>BIKE</span>
            </h1>
            <p className="text-[0.9rem] font-medium text-white/90">Smart motorbike care · Admin Console</p>
          </div>

          {/* Features */}
          <div className="flex flex-col gap-5">
            {FEATURES.map(({ icon: Icon, text }) => (
              <div key={text} className="flex items-center gap-4">
                <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-white/25">
                  <Icon size={20} color="white" strokeWidth={2} />
                </span>
                <span className="text-[0.9375rem] font-bold text-white">{text}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* ── Right form panel ─────────────────────────────────────── */}
      <div className="flex flex-1 flex-col bg-[#faf6f0]">
        {/* Centered card */}
        <div className="flex flex-1 items-center justify-center px-6 py-12">
          <div className="w-full max-w-105">
            <div className="overflow-hidden rounded-2xl bg-white shadow-[0_8px_40px_rgba(0,0,0,0.10)]">

              {/* Orange gradient top accent */}
              <div className="h-0.75 w-full bg-linear-to-r from-orange-500 via-orange-400 to-amber-400" />

              <div className="p-8">
                {/* STAFF ACCESS badge */}
                <div className="mb-5 inline-flex items-center gap-1.5 rounded-full border border-orange-100 bg-orange-50 px-3 py-1.5">
                  <Shield size={12} className="text-orange-500" />
                  <span className="text-[0.65rem] font-bold uppercase tracking-[0.18em] text-orange-500">
                    Staff Access
                  </span>
                </div>

                <h2 className="mb-1 text-2xl font-extrabold tracking-tight text-stone-900">Sign in</h2>
                <p className="mb-6 text-sm leading-normal text-stone-500">
                  Welcome back — for Administrators &amp; Branches
                </p>

                {/* Error alert */}
                {error && (
                  <div
                    className="mb-4 flex items-start gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-normal text-red-600"
                    role="alert"
                  >
                    <AlertCircle size={16} className="mt-px shrink-0" aria-hidden="true" />
                    <span>{error}</span>
                  </div>
                )}

                <form className="flex flex-col gap-5" onSubmit={handleSubmit} noValidate>

                  {/* Username */}
                  <div className="flex flex-col gap-1.5">
                    <label className="flex items-center gap-1 text-sm font-semibold text-stone-700" htmlFor="username">
                      <span className="text-orange-500">•</span> Username
                    </label>
                    <div className="relative">
                      <User
                        size={15}
                        className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-stone-400"
                      />
                      <input
                        id="username"
                        name="username"
                        type="text"
                        className="w-full rounded-xl border border-stone-200 bg-stone-50 py-2.5 pl-10 pr-4 text-sm text-stone-800 placeholder:text-stone-400 transition-[border-color,box-shadow] duration-150 hover:border-stone-300 focus:border-orange-400 focus:bg-white focus:outline-none focus:shadow-[0_0_0_3px_rgba(249,115,22,0.15)] disabled:cursor-not-allowed disabled:opacity-60"
                        placeholder="Enter your email or username..."
                        autoComplete="username"
                        autoFocus
                        value={form.username}
                        onChange={handleChange}
                        disabled={isSubmitting}
                        aria-invalid={!!error}
                        required
                      />
                    </div>
                  </div>

                  {/* Password */}
                  <div className="flex flex-col gap-1.5">
                    <label className="flex items-center gap-1 text-sm font-semibold text-stone-700" htmlFor="password">
                      <span className="text-orange-500">•</span> Password
                    </label>
                    <div className="relative">
                      <Lock
                        size={15}
                        className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-stone-400"
                      />
                      <input
                        id="password"
                        name="password"
                        type={showPassword ? 'text' : 'password'}
                        className="w-full rounded-xl border border-stone-200 bg-stone-50 py-2.5 pl-10 pr-11 text-sm text-stone-800 placeholder:text-stone-400 transition-[border-color,box-shadow] duration-150 hover:border-stone-300 focus:border-orange-400 focus:bg-white focus:outline-none focus:shadow-[0_0_0_3px_rgba(249,115,22,0.15)] disabled:cursor-not-allowed disabled:opacity-60"
                        placeholder="Enter your password..."
                        autoComplete="current-password"
                        value={form.password}
                        onChange={handleChange}
                        disabled={isSubmitting}
                        aria-invalid={!!error}
                        required
                      />
                      <button
                        type="button"
                        className="absolute right-3 top-1/2 -translate-y-1/2 border-none bg-transparent p-1 text-stone-400 transition-colors hover:text-stone-600"
                        onClick={() => setShowPassword((v) => !v)}
                        aria-label={showPassword ? 'Hide password' : 'Show password'}
                        tabIndex={-1}
                      >
                        {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                      </button>
                    </div>
                  </div>

                  {/* Submit */}
                  <button
                    type="submit"
                    className="mt-1 flex w-full items-center justify-center gap-2 rounded-xl bg-linear-to-r from-[#fb923c] via-[#f97316] to-[#ea580c] py-3 text-sm font-bold text-white shadow-[0_8px_24px_rgba(249,115,22,0.35)] transition-all duration-200 hover:-translate-y-0.5 hover:shadow-[0_10px_28px_rgba(249,115,22,0.45)] active:translate-y-0 disabled:cursor-not-allowed disabled:opacity-65 disabled:hover:translate-y-0"
                    disabled={isSubmitting}
                    aria-busy={isSubmitting}
                  >
                    {isSubmitting ? (
                      <>
                        <LoadingSpinner size={17} color="#fff" />
                        <span>Signing in...</span>
                      </>
                    ) : (
                      <>
                        Sign in
                        <ArrowRight size={16} strokeWidth={2.5} />
                      </>
                    )}
                  </button>

                </form>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>
  );
};

export default Login;
