import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { AuthLoadingScreen } from '../components/auth/AuthLayout';
import type { UserRole } from '../types/auth';

interface RoleRouteProps {
  allowedRoles: UserRole[];
}

const RoleRoute = ({ allowedRoles }: RoleRouteProps) => {
  const { user, isAuthenticated, isLoading } = useAuth();

  if (isLoading) return <AuthLoadingScreen />;
  if (!isAuthenticated) return <Navigate to="/login" replace />;

  if (!user || !allowedRoles.includes(user.role)) {
    // Authenticated but wrong role → go back to dashboard
    return <Navigate to="/" replace />;
  }

  return <Outlet />;
};

export default RoleRoute;
