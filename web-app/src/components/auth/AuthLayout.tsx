import { Bike } from 'lucide-react';
import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import LoadingSpinner from '../ui/LoadingSpinner';

interface AuthLayoutProps {
  children: ReactNode;
  wide?: boolean;
}

export function AuthLayout({ children, wide }: AuthLayoutProps) {
  return (
    <div className="auth-page">
      <div className={wide ? 'auth-shell auth-shell--wide' : 'auth-shell'}>
        <header className="auth-brand">
          <Link to="/login" className="auth-brand-link">
            <span className="auth-brand-icon" aria-hidden="true">
              <Bike size={28} strokeWidth={2} color="#fff" />
            </span>
            <div>
              <h1 className="auth-brand-name">CareBike</h1>
              <p className="auth-brand-tagline">
                Hệ thống quản lý bảo dưỡng xe máy
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
    <div className="auth-loading-screen" role="status" aria-live="polite">
      <LoadingSpinner size={24} color="#fff" />
      <span style={{ marginLeft: '0.75rem' }}>Đang tải...</span>
    </div>
  );
}
