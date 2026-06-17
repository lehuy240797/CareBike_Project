import { useState, useEffect, useCallback } from 'react';
import { UserCog, Plus, Lock, Unlock, Trash2 } from 'lucide-react';
import { apiGetAllUsers, apiToggleUserStatus, apiDeleteUser } from '../services/userService';
import type { UserRecord } from '../services/userService';
import StaffModal from '../components/modals/StaffModal';


const StaffManagement = () => {
    const [staffs, setStaffs] = useState<UserRecord[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [isModalOpen, setIsModalOpen] = useState(false);

    const fetchStaffs = useCallback(async () => {
        try {
            setIsLoading(true);
            const data = await apiGetAllUsers();
            // Lọc ra những người dùng có role là BRANCH
            const branchManagers = data.filter(u => u.role?.roleName === 'BRANCH');
            setStaffs(branchManagers);
        } catch (error) {
            console.error("Lỗi tải danh sách nhân sự", error);
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => { fetchStaffs(); }, [fetchStaffs]);

    const handleToggleStatus = async (id: number) => {
        try {
            await apiToggleUserStatus(id);
            fetchStaffs(); // Refresh lại danh sách sau khi khóa/mở
        } catch (error) {
            alert("Không thể thay đổi trạng thái tài khoản này.");
        }
    };

    const handleDeleteStaff = async (id: number, name: string) => {
        const confirmDelete = window.confirm(`Bạn có chắc chắn muốn XÓA VĨNH VIỄN tài khoản của "${name}" không?\nHành động này sẽ xóa sạch dữ liệu trên cả Firebase.`);
        if (!confirmDelete) return;

        try {
            await apiDeleteUser(id);
            alert("Đã xóa tài khoản thành công!");
            fetchStaffs(); // Tải lại danh sách mới sạch sẽ
        } catch (error: any) {
            // Hiển thị câu chặn của Backend lên màn hình (Ví dụ: Đang bận quản lý chi nhánh)
            const msg = error?.response?.data?.message ?? "Không thể xóa tài khoản này.";
            alert(msg);
        }
    };

    return (
        <>
            <div className="dashboard-inner">
                <div className="page-header" style={{ marginBottom: '1.75rem' }}>
                    <UserCog size={28} className="page-header-icon" aria-hidden="true" />
                    <div style={{ flex: 1 }}>
                        <h1 className="dashboard-title" style={{ margin: 0 }}>Quản lý Nhân sự</h1>
                        <p className="page-subtitle">Danh sách tài khoản Quản lý chi nhánh</p>
                    </div>
                    <button type="button" className="app-btn" onClick={() => setIsModalOpen(true)}>
                        <Plus size={16} aria-hidden="true" /> Tạo tài khoản mới
                    </button>
                </div>

                <div className="table-card">
                    {isLoading ? (
                        <div className="table-empty"><p>Đang tải dữ liệu...</p></div>
                    ) : staffs.length === 0 ? (
                        <div className="table-empty">
                            <UserCog size={40} style={{ opacity: 0.3 }} />
                            <p>Chưa có tài khoản quản lý nào.</p>
                        </div>
                    ) : (
                        <div className="table-scroll">
                            <table className="data-table">
                                <thead>
                                    <tr>
                                        <th>#ID</th>
                                        <th>Họ và tên</th>
                                        <th>Email đăng nhập</th>
                                        <th>Điện thoại</th>
                                        <th>Trạng thái</th>
                                        <th style={{ textAlign: 'right' }}>Khóa / Mở</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {staffs.map((staff) => (
                                        <tr key={staff.id}>
                                            <td className="td-muted">{staff.id}</td>
                                            <td className="font-medium">{staff.fullName || '—'}</td>
                                            <td className="td-primary">{staff.email}</td>
                                            <td>{staff.phone || '—'}</td>
                                            <td>
                                                <span className={staff.isActive ? 'badge badge--success' : 'badge badge--danger'}>
                                                    {staff.isActive ? 'Hoạt động' : 'Đã khóa'}
                                                </span>
                                            </td>
                                            <td>
                                                <div className="table-actions">
                                                    <button
                                                        type="button"
                                                        onClick={() => handleToggleStatus(staff.id)}
                                                        className={`icon-btn ${staff.isActive ? 'icon-btn--delete' : 'icon-btn--edit'}`}
                                                        title={staff.isActive ? "Khóa tài khoản" : "Mở khóa tài khoản"}
                                                    >
                                                        {staff.isActive ? <Lock size={15} /> : <Unlock size={15} />}
                                                    </button>
                                                    <button
                                                        type="button"
                                                        onClick={() => handleDeleteStaff(staff.id, staff.fullName || staff.email)}
                                                        className="icon-btn icon-btn--delete"
                                                        title="Xóa vĩnh viễn"
                                                        style={{ marginLeft: '8px' }}
                                                    >
                                                        <Trash2 size={15} color="var(--color-danger, #ef4444)" />
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    )}
                </div>
            </div>

            {isModalOpen && (
                <StaffModal
                    onClose={() => setIsModalOpen(false)}
                    onSuccess={() => { setIsModalOpen(false); fetchStaffs(); }}
                />
            )}
        </>
    );
};

export default StaffManagement;