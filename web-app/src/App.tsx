import { BrowserRouter, Navigate, Outlet, Route, Routes } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';
import { WebSocketProvider } from './context/WebSocketContext';
import ProtectedRoute from './routes/ProtectedRoute';
import RoleRoute from './routes/RoleRoute';
import Layout from './components/Layout';

import Login from './pages/Login';
import ChangePassword from './pages/ChangePassword';
import CategoryManagement from './pages/CategoryManagement';
import BranchManagement from './pages/BranchManagement';
import CustomerManagement from './pages/CustomerManagement';
import StaffManagement from './pages/StaffManagement';
import AdminDashboard from './pages/AdminDashboard';
import BranchDashboard from './pages/BranchDashboard';
import SparePartManagement from './pages/SparePartManagement';
import VehicleTireSpecManagement from './pages/VehicleTireSpecManagement';
import BranchShiftManagement from './pages/BranchShiftManagement';
import BranchRequestHistory from './pages/BranchRequestHistory';
import BranchStaffManagement from './pages/BranchStaffManagement';
import BranchStaffKpi from './pages/BranchStaffKpi';

const GlobalWebSocketWrapper = () => {
  const { user } = useAuth();
  return (
    <WebSocketProvider branchId={user?.branchId}>
      <Outlet />
    </WebSocketProvider>
  );
};

const DashboardRouter = () => {
  const { user } = useAuth();
  if (user?.role === 'ADMIN') return <AdminDashboard />;
  return <BranchDashboard />;
};

const App = () => {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Toaster position="top-right" reverseOrder={false} />
        <Routes>
          <Route path="/login" element={<Login />} />

          <Route element={<ProtectedRoute />}>
            <Route element={<GlobalWebSocketWrapper />}>
              <Route element={<Layout />}>
                <Route index element={<DashboardRouter />} />
                <Route path="change-password" element={<ChangePassword />} />

                <Route element={<RoleRoute allowedRoles={['BRANCH']} />}>
                  <Route path="branch-staff" element={<BranchStaffManagement />} />
                  <Route path="shifts" element={<BranchShiftManagement />} />
                  <Route path="history" element={<BranchRequestHistory />} />
                  <Route path="staff-kpi" element={<BranchStaffKpi />} />
                </Route>

                <Route element={<RoleRoute allowedRoles={['ADMIN']} />}>
                  <Route path="staff" element={<StaffManagement />} />
                  <Route path="branches" element={<BranchManagement />} />
                  <Route path="customers" element={<CustomerManagement />} />
                  <Route path="categories" element={<CategoryManagement />} />
                  <Route path="spare-parts" element={<SparePartManagement />} />
                  <Route path="tire-specs" element={<VehicleTireSpecManagement />} />
                </Route>
              </Route>
            </Route>
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default App;
