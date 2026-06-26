import { Bike } from 'lucide-react';
import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import LoadingSpinner from '../ui/LoadingSpinner';

interface AuthLayoutProps {
  children: ReactNode;
  wide?: boolean;
}

const AUTH_BG =
  '[background:linear-gradient(150deg,#9a3412_0%,#ea580c_42%,#f97316_72%,#fb923c_100%)]';

export function AuthLayout({ children, wide }: AuthLayoutProps) {
  return (
    <div
      className={`relative flex min-h-screen items-center justify-center overflow-hidden p-6 bg-[length:200%_200%] animate-gradient-slow ${AUTH_BG}`}
    >
      {/* Soft light/shadow overlay */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 [background:radial-gradient(ellipse_at_18%_18%,rgba(255,255,255,0.09)_0%,transparent_50%),radial-gradient(ellipse_at_82%_82%,rgba(0,0,0,0.18)_0%,transparent_50%)]"
      />
      {/* Drifting aurora orbs */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -inset-[20%] z-0 blur-[10px] animate-aurora [background:radial-gradient(38%_38%_at_20%_25%,rgba(253,224,71,0.40),transparent_70%),radial-gradient(34%_34%_at_82%_22%,rgba(251,113,133,0.38),transparent_70%),radial-gradient(42%_42%_at_70%_85%,rgba(255,237,213,0.35),transparent_70%)]"
      />

      <div className={`relative z-[2] w-full ${wide ? 'max-w-[560px]' : 'max-w-[440px]'}`}>
        <header className="mb-7 text-center text-white animate-fade-up">
          <Link
            to="/login"
            className="group inline-flex flex-col items-center gap-3 text-inherit no-underline transition-opacity hover:opacity-95"
          >
            <span
              className="flex h-14 w-14 items-center justify-center rounded-full border border-white/35 bg-white/[0.18] backdrop-blur-md shadow-[0_8px_28px_rgba(124,45,18,0.25)] animate-float transition-transform duration-200 group-hover:scale-105"
              aria-hidden="true"
            >
              <Bike size={28} strokeWidth={2} color="#fff" />
            </span>
            <div>
              <h1 className="m-0 font-racing text-4xl uppercase tracking-[5px] [text-shadow:0_2px_14px_rgba(124,45,18,0.30)]">
                CareBike
              </h1>
              <p className="mt-1.5 mb-0 font-orb text-[0.7rem] uppercase tracking-[2px] opacity-85">
                Motorbike Maintenance Management System
              </p>
            </div>
          </Link>
        </header>
        {children}
      </div>
    </div>
  );
}

export function AuthLoadingScreen() {
  return (
    <div
      className={`flex min-h-screen items-center justify-center gap-3 text-[0.9375rem] text-white ${AUTH_BG}`}
      role="status"
      aria-live="polite"
    >
      <LoadingSpinner size={24} color="#fff" />
      <span className="ml-3">Loading...</span>
    </div>
  );
}
