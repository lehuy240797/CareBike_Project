import React from 'react';
import { useAuth } from '../context/AuthContext';
import { dashTitle, eyebrow, pageSubtitle } from '../ui/styles';

const BranchDashboard: React.FC = () => {
    const { user } = useAuth();

<<<<<<< HEAD
    // LẤY ID CHI NHÁNH TỪ USER HIỆN TẠI (Vẫn giữ lại biến này phòng khi bạn cần gọi API thống kê khác)
    // const currentBranchId = (user as any)?.branchId;

    return (
        <div className="dashboard-inner">
            <div className="page-header" style={{ marginBottom: '2rem' }}>
                <LayoutDashboard size={28} className="page-header-icon" aria-hidden="true" />
                <div>
                    <h1 className="dashboard-title" style={{ margin: 0 }}>
                        Welcome, {user?.username ?? 'user'} 👋
                    </h1>
                    <p className="page-subtitle">Your Branch Overview</p>
                </div>
=======
    // Get the branch ID from the current user (kept in case other stats APIs need it)
    const currentBranchId = (user as any)?.branchId;

    return (
        <div className="mx-auto max-w-[72rem]">
            <div className="mb-10 animate-fade-up">
                <p className={eyebrow}>Overview</p>
                <h1 className={`${dashTitle} mt-2`}>Hello, {user?.username ?? 'there'} 👋</h1>
                <p className={pageSubtitle}>Your branch activity overview</p>
>>>>>>> 492036b821510e5bc8b94cc4f674d63891445bc7
            </div>
        </div>
    );
};

export default BranchDashboard;