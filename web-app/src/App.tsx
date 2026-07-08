import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import ProtectedRoute from './routes/ProtectedRoute';
import RoleRoute from './routes/RoleRoute';
import Layout from './components/Layout';
import { Toaster } from 'react-hot-toast';

// Pages
import Login from './pages/Login';
import ChangePassword from './pages/ChangePassword';
import CategoryManagement from './pages/CategoryManagement';
import BranchManagement from './pages/BranchManagement';
import CustomerManagement from './pages/CustomerManagement';
import StaffManagement from './pages/StaffManagement';
import AdminDashboard from './pages/AdminDashboard';
import BranchDashboard from './pages/BranchDashboard';
import SparePartManagement from './pages/SparePartManagement';
import BranchShiftManagement from './pages/BranchShiftManagement';
import BranchRequestHistory from './pages/BranchRequestHistory';

const DashboardRouter = () => {
  const { user } = useAuth();
  if (user?.role === 'ADMIN') return <AdminDashboard />;
  return <BranchDashboard />;
};

const App = () => {
  return (
    <BrowserRouter>
      <Toaster position="top-right" reverseOrder={false} />
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />

          <Route element={<ProtectedRoute />}>
            <Route element={<Layout />}>
              <Route index element={<DashboardRouter />} />
              <Route path="change-password" element={<ChangePassword />} />
              
              {/* Branch Routes */}
              <Route element={<RoleRoute allowedRoles={['BRANCH']} />}>
                <Route path="shifts" element={<BranchShiftManagement />} />
                <Route path="history" element={<BranchRequestHistory />} />
              </Route>

              {/* Admin Routes */}
              <Route element={<RoleRoute allowedRoles={['ADMIN']} />}>
                <Route path="staff" element={<StaffManagement />} />
                <Route path="branches" element={<BranchManagement />} />
                <Route path="customers" element={<CustomerManagement />} />
                {/* Product Management */}
                <Route path="categories" element={<CategoryManagement />} />
                {/* MỚI: Route cho Phụ tùng */}
                <Route path="spare-parts" element={<SparePartManagement />} />
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