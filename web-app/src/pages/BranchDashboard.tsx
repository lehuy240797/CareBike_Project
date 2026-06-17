import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { Client } from '@stomp/stompjs';
import {
    LayoutDashboard,
    Clock,
    CheckCircle2,
    Check,
    X,
    Calendar,
    User as UserIcon,
    FileText
} from 'lucide-react';
import { appointmentService } from '../services/appointmentService';
import type { AppointmentRecord } from '../types/api';

import RescueDashboard from './RescueDashboard';

const BranchDashboard: React.FC = () => {
    const { user } = useAuth();
    const [pendingAppointments, setPendingAppointments] = useState<AppointmentRecord[]>([]);
    const [loading, setLoading] = useState(false);

    // LẤY ID CHI NHÁNH TỪ USER HIỆN TẠI
    const currentBranchId = (user as any)?.branchId;

    useEffect(() => {
        if (currentBranchId) {
            loadPendingAppointments(currentBranchId);
        }
    }, [currentBranchId]);

    const loadPendingAppointments = async (branchId: number) => {
        try {
            setLoading(true);
            const data = await appointmentService.getPendingAppointments(branchId);
            setPendingAppointments(data);
        } catch (error) {
            console.error('Lỗi khi tải danh sách lịch hẹn:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (!currentBranchId) return;

        const stompClient = new Client({
            brokerURL: 'ws://localhost:8080/ws',
            reconnectDelay: 5000,
            debug: (str) => console.log('STOMP (Branch):', str),
        });

        stompClient.onConnect = () => {
            console.log('Đã kết nối WebSocket thành công cho Chi nhánh!');

            stompClient.subscribe(`/topic/branches/${currentBranchId}/appointments`, (message) => {
                if (message.body) {
                    const newAppointment = JSON.parse(message.body);
                    setPendingAppointments((prev) => [newAppointment, ...prev]);
                    alert(`CÓ ĐƠN MỚI: Khách hàng ${newAppointment.customerName || 'ẩn danh'} vừa đặt lịch!`);
                }
            });
        };

        stompClient.onStompError = (frame) => {
            console.error('Lỗi WebSocket STOMP:', frame.headers['message']);
        };

        stompClient.activate();

        return () => {
            stompClient.deactivate();
        };
    }, [currentBranchId]);

    const handleUpdateStatus = async (id: number, status: 'PENDING' | 'CONFIRMED' | 'COMPLETED' | 'CANCELLED') => {
        try {
            await appointmentService.updateStatus(id, status);
            if (currentBranchId) loadPendingAppointments(currentBranchId);
        } catch (error) {
            console.error('Lỗi cập nhật trạng thái:', error);
            alert('Không thể cập nhật trạng thái lịch hẹn.');
        }
    };

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

            {/* 👉 BƯỚC 2 & 3: NHÚNG MODULE CỨU HỘ VÀ TRUYỀN ID VÀO */}
            <div style={{ marginBottom: '3rem' }}>
                {currentBranchId ? (
                    <RescueDashboard branchId={currentBranchId} />
                ) : (
                    <div className="p-4 text-gray-500 italic border rounded-lg">
                        Đang xác định thông tin chi nhánh...
                    </div>
                )}
            </div>

            {/* PHẦN DƯỚI LÀ TABLE LỊCH HẸN BẢO DƯỠNG CŨ CỦA BẠN (GIỮ NGUYÊN) */}
            <div className="dashboard-table-card">
                <div className="table-card-header">
                    <h2 className="section-heading" style={{ margin: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <Clock size={22} color="#f59e0b" />
                        Lịch hẹn chờ xác nhận
                    </h2>
                    {pendingAppointments.length > 0 && (
                        <span className="badge-count">{pendingAppointments.length} đơn chờ</span>
                    )}
                </div>

                <div className="table-container">
                    {loading ? (
                        <div className="table-empty-state">
                            <div className="spinner"></div>
                            <p>Đang tải dữ liệu...</p>
                        </div>
                    ) : pendingAppointments.length === 0 ? (
                        <div className="table-empty-state">
                            <CheckCircle2 size={40} color="#10b981" style={{ marginBottom: '12px', opacity: 0.5 }} />
                            <p>Tuyệt vời! Hiện không có lịch hẹn nào đang chờ xử lý.</p>
                        </div>
                    ) : (
                        <table className="modern-table">
                            <thead>
                                <tr>
                                    <th>THỜI GIAN</th>
                                    <th>KHÁCH HÀNG</th>
                                    <th>GHI CHÚ</th>
                                    <th style={{ width: 220, textAlign: 'center' }}>THAO TÁC</th>
                                </tr>
                            </thead>
                            <tbody>
                                {pendingAppointments.map((apt) => {
                                    const date = new Date(apt.appointmentDate);
                                    const timeString = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
                                    const dateString = `${date.getDate().toString().padStart(2, '0')}/${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getFullYear()}`;

                                    return (
                                        <tr key={apt.id}>
                                            <td>
                                                <div className="td-flex">
                                                    <Calendar size={16} className="text-muted" />
                                                    <div>
                                                        <div className="font-medium text-primary">{timeString}</div>
                                                        <div className="text-sm text-muted">{dateString}</div>
                                                    </div>
                                                </div>
                                            </td>
                                            <td>
                                                <div className="td-flex">
                                                    <div className="avatar-placeholder">
                                                        <UserIcon size={16} />
                                                    </div>
                                                    <span className="font-semibold">{apt.customerName || 'Khách hàng ẩn danh'}</span>
                                                </div>
                                            </td>
                                            <td>
                                                <div className="td-flex text-muted" style={{ fontSize: '0.9rem' }}>
                                                    <FileText size={16} style={{ flexShrink: 0 }} />
                                                    <span className="truncate-text">{apt.note || 'Không có ghi chú thêm'}</span>
                                                </div>
                                            </td>
                                            <td>
                                                <div className="action-buttons">
                                                    <button onClick={() => handleUpdateStatus(apt.id, 'CONFIRMED')} className="btn-soft btn-soft-success" title="Xác nhận nhận xe">
                                                        <Check size={16} /><span>Nhận xe</span>
                                                    </button>
                                                    <button onClick={() => handleUpdateStatus(apt.id, 'CANCELLED')} className="btn-soft btn-soft-danger" title="Từ chối lịch hẹn">
                                                        <X size={16} /><span>Hủy</span>
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    )}
                </div>
            </div>
        </div>
    );
};

export default BranchDashboard;