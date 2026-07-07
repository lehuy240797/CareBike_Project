import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext'; // Bổ sung useAuth
import ProtectedRoute from './routes/ProtectedRoute';
import RoleRoute from './routes/RoleRoute';
import Layout from './components/Layout';
import { Toaster } from 'react-hot-toast'; // Import thư viện Toast báo lỗi xịn xò


// Pages
import Login from './pages/Login';
import ChangePassword from './pages/ChangePassword';
import BranchManagement from './pages/BranchManagement';
import CustomerManagement from './pages/CustomerManagement';
import StaffManagement from './pages/StaffManagement';
import AdminDashboard from './pages/AdminDashboard';
import BranchDashboard from './pages/BranchDashboard';
import Revenue from './pages/Revenue';

// =========================================================================
// TRẠM ĐIỀU HƯỚNG DASHBOARD (PROXY COMPONENT)
// =========================================================================
const DashboardRouter = () => {
  const { user } = useAuth();

  // Dựa vào Role để quyết định hiển thị màn hình nào cho trang chủ (index)
  if (user?.role === 'ADMIN') {
    return <AdminDashboard />;
  }

  // Mặc định trả về BranchDashboard (vì Customer đã bị Spring Boot chặn không cho lên Web)
  return <BranchDashboard />;
};

const App = () => {
  return (
    // BrowserRouter phải bọc AuthProvider để AuthProvider có thể gọi useNavigate
    <BrowserRouter>
      {/* Gắn cái Toaster ở root để chỗ nào cũng gọi báo lỗi hiển thị đẹp được */}
      <Toaster position="top-right" reverseOrder={false} />
      <AuthProvider>
        <Routes>
          {/* ── Public routes ─────────────────────────────────────────────── */}
          <Route path="/login" element={<Login />} />

          {/* ── Protected routes (any authenticated role) ─────────────────── */}
          <Route element={<ProtectedRoute />}>
            <Route element={<Layout />}>

              {/* Sử dụng trạm điều hướng thay vì fix cứng 1 Dashboard */}
              <Route index element={<DashboardRouter />} />

              <Route path="change-password" element={<ChangePassword />} />
              <Route path="revenue" element={<Revenue />} />

              {/* ── Admin-only routes ──────────────────────────────────────── */}
              <Route element={<RoleRoute allowedRoles={['ADMIN']} />}>
                <Route path="staff" element={<StaffManagement />} />
                <Route path="branches" element={<BranchManagement />} />
                <Route path="customers" element={<CustomerManagement />} />
              </Route>
            </Route>
          </Route>

          {/* ── Catch-all ─────────────────────────────────────────────────── */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default App;