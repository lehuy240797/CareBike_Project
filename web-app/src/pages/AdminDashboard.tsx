import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Client } from '@stomp/stompjs';
import {
  LayoutDashboard,
  Building2,
  Users,
  TrendingUp,
  Clock,
  CheckCircle2,
  Wrench,
  UserCog
} from 'lucide-react';

// Khởi tạo giá trị mặc định cho thống kê
const INITIAL_STATS = [
  { id: 'today', label: 'Đơn bảo dưỡng hôm nay', value: 24, icon: <Wrench size={20} />, color: 'var(--color-primary)' },
  { id: 'processing', label: 'Đang xử lý', value: 15, icon: <Clock size={20} />, color: '#f59e0b' },
  { id: 'completed', label: 'Hoàn thành', value: 82, icon: <CheckCircle2 size={20} />, color: '#10b981' },
  { id: 'revenue', label: 'Doanh thu tháng (M₫)', value: 4.5, icon: <TrendingUp size={20} />, color: '#8b5cf6' },
];

const AdminDashboard: React.FC = () => {
  const { user } = useAuth();
  const [stats, setStats] = useState(INITIAL_STATS);

  // Tích hợp WebSocket (STOMP) để thống kê nhảy số Real-time
  useEffect(() => {
    const stompClient = new Client({
      brokerURL: 'ws://localhost:8080/ws',
      reconnectDelay: 5000,
      debug: (str) => console.log('STOMP (Admin):', str),
    });

    stompClient.onConnect = () => {
      console.log('Đã kết nối WebSocket thành công cho Admin!');

      // Lắng nghe kênh thông báo tổng (Yêu cầu Backend bắn tin nhắn vào /topic/admin/stats)
      stompClient.subscribe('/topic/admin/stats', (message) => {
        if (message.body) {
          // Logic ví dụ: Tăng số lượng đơn hôm nay lên 1 khi có đơn mới toàn hệ thống
          setStats((prevStats) =>
            prevStats.map(stat =>
              stat.id === 'today' ? { ...stat, value: stat.value + 1 } : stat
            )
          );
        }
      });
    };

    stompClient.onStompError = (frame) => {
      console.error('Lỗi WebSocket STOMP Admin:', frame.headers['message']);
    };

    stompClient.activate();

    return () => {
      stompClient.deactivate();
    };
  }, []);

  return (
    <div className="dashboard-inner">
      <div className="page-header" style={{ marginBottom: '2rem' }}>
        <LayoutDashboard size={28} className="page-header-icon" aria-hidden="true" />
        <div>
          <h1 className="dashboard-title" style={{ margin: 0 }}>
            Xin chào Quản trị viên, {user?.username ?? ''} 👋
          </h1>
          <p className="page-subtitle">Tổng quan toàn hệ thống CareBike</p>
        </div>
      </div>

      {/* Stats grid real-time */}
      <div className="dashboard-grid">
        {stats.map((stat) => (
          <div className="dashboard-stat-card" key={stat.id}>
            <div className="dashboard-stat-icon" style={{ color: stat.color }}>
              {stat.icon}
            </div>
            <div className="dashboard-stat-body">
              <span className="dashboard-stat-value">
                {stat.id === 'revenue' ? `${stat.value}M₫` : stat.value}
              </span>
              <span className="dashboard-stat-label">{stat.label}</span>
            </div>
          </div>
        ))}
      </div>

      <h2 className="section-heading" style={{ marginTop: '2.5rem' }}>Quản lý nhanh</h2>
      <div className="dashboard-panel-grid">
        <div className="dashboard-panel">
          <div className="dashboard-panel-header">
            <UserCog size={20} aria-hidden="true" />
            <h3>Tài khoản Nhân sự</h3>
          </div>
          <p>Tạo tài khoản và cấp quyền cho các Quản lý chi nhánh.</p>
          <Link to="/staff" className="app-btn dashboard-panel-btn">
            Đến Quản lý Nhân sự
          </Link>
        </div>

        <div className="dashboard-panel">
          <div className="dashboard-panel-header">
            <Building2 size={20} aria-hidden="true" />
            <h3>Cơ sở vật chất</h3>
          </div>
          <p>Quản lý các chi nhánh vật lý và phân công người quản lý.</p>
          <Link to="/branches" className="app-btn dashboard-panel-btn">
            Đến Quản lý Chi nhánh
          </Link>
        </div>

        <div className="dashboard-panel">
          <div className="dashboard-panel-header">
            <Users size={20} aria-hidden="true" />
            <h3>Tài khoản Khách hàng</h3>
          </div>
          <p>Xem danh sách người dùng ứng dụng và lịch sử bảo dưỡng.</p>
          <Link to="/customers" className="app-btn dashboard-panel-btn">
            Đến Quản lý Khách hàng
          </Link>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;