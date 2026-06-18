import React from 'react';
import { useAuth } from '../context/AuthContext';
import { LayoutDashboard } from 'lucide-react';

const BranchDashboard: React.FC = () => {
    const { user } = useAuth();

    // LẤY ID CHI NHÁNH TỪ USER HIỆN TẠI (Vẫn giữ lại biến này phòng khi bạn cần gọi API thống kê khác)
    const currentBranchId = (user as any)?.branchId;

    return (
        <div className="dashboard-inner">
            <div className="page-header" style={{ marginBottom: '2rem' }}>
                <LayoutDashboard size={28} className="page-header-icon" aria-hidden="true" />
                <div>
                    <h1 className="dashboard-title" style={{ margin: 0 }}>
                        Xin chào, {user?.username ?? 'bạn'} 👋
                    </h1>
                    <p className="page-subtitle">Tổng quan hoạt động chi nhánh của bạn</p>
                </div>
            </div>
        </div>
    );
};

export default BranchDashboard;