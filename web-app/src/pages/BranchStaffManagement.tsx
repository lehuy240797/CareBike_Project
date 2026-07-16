import { useState, useEffect, useCallback } from 'react';
import { Plus, Trash2, Search, Users, Wrench, RefreshCw } from 'lucide-react';
import { apiGetStaffByBranch, apiDeleteStaff, apiUpdateStaffStatus } from '../services/staffService';
import type { StaffRecord } from '../services/staffService';
import BranchStaffModal from '../components/modals/BranchStaffModal';
import toast from 'react-hot-toast';
import { useAuth } from '../context/AuthContext';
import { useWebSocketEvent } from '../context/WebSocketContext';
import {
    btnPrimary, dashTitle, eyebrow, iconBtnDelete, iconBtnEdit,
    tableCard, tableEmpty, dataTable, tableScroll, tableSpinner, tdCell, thCell, tableRow,
} from '../ui/styles';

const searchInput = 'w-full rounded-2xl border border-edge bg-primary-light/40 py-2.5 pl-10 pr-4 text-sm outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary/20';
const ITEMS_PER_PAGE = 10;

const BranchStaffManagement = () => {
    const { user } = useAuth();
    const branchId = (user as { branchId?: number })?.branchId;

    const [staffs, setStaffs] = useState<StaffRecord[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [selectedStaff, setSelectedStaff] = useState<StaffRecord | null>(null);
    const [search, setSearch] = useState('');
    const [currentPage, setCurrentPage] = useState(1);

    const fetchStaffs = useCallback(async (background = false) => {
        if (!branchId) {
            if (!background) setIsLoading(false);
            return;
        }
        try {
            if (!background) setIsLoading(true);
            const data = await apiGetStaffByBranch(branchId);
            setStaffs(data);
        } catch (error) {
            console.error("Failed to load staff list", error);
            toast.error("Failed to load mechanics.");
        } finally {
            if (!background) setIsLoading(false);
        }
    }, [branchId]);

    useWebSocketEvent('STAFF_UPDATED', () => fetchStaffs(true));
    useWebSocketEvent('SHIFT_UPDATED', () => fetchStaffs(true));

    useEffect(() => { fetchStaffs(); }, [fetchStaffs]);

    const handleEdit = (staff: StaffRecord) => {
        setSelectedStaff(staff);
        setIsModalOpen(true);
    };

    const handleResetStatus = async (staffId: number) => {
        try {
            await apiUpdateStaffStatus(staffId, 'FREE');
            toast.success('Mechanic status reset to FREE');
            fetchStaffs(true);
        } catch (error: any) {
            toast.error('Failed to reset status');
        }
    };

    const handleDelete = async (staffId: number, name: string) => {
        const confirmDelete = window.confirm(`Are you sure you want to remove mechanic "${name}"?`);
        if (!confirmDelete) return;

        try {
            await apiDeleteStaff(staffId);
            toast.success("Mechanic removed successfully!");
            fetchStaffs();
        } catch (error: any) {
            toast.error(error?.response?.data?.message ?? "Could not remove mechanic.");
        }
    };

    const filtered = staffs.filter((s) => {
        if (!search) return true;
        return [s.fullName, s.staffCode, s.phone].some((v) =>
            v?.toLowerCase().includes(search.toLowerCase())
        );
    });
    const totalPages = Math.max(1, Math.ceil(filtered.length / ITEMS_PER_PAGE));
    const page = Math.min(currentPage, totalPages);
    const pageStart = (page - 1) * ITEMS_PER_PAGE;
    const paginatedStaffs = filtered.slice(pageStart, pageStart + ITEMS_PER_PAGE);


    return (
        <>
            <div className="mx-auto max-w-[80rem]">
                <div className="mb-8 flex items-start justify-between gap-4 animate-fade-up">
                    <div>
                        <p className={eyebrow}>Branch Mechanics</p>
                        <h1 className={`${dashTitle} mt-1`}>Mechanics Management</h1>
                        <p className="mt-1.5 font-pop text-sm text-ink-muted">
                            Manage mechanics and their details for your branch.
                        </p>
                    </div>
                    <button type="button" className={btnPrimary} onClick={() => { setSelectedStaff(null); setIsModalOpen(true); }}>
                        <Plus size={16} aria-hidden="true" /> Add Mechanic
                    </button>
                </div>

                <div className="mb-6 rounded-3xl border border-edge bg-white p-4 shadow-sm">
                    <div className="relative min-w-48 max-w-md">
                        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted" aria-hidden="true" />
                        <input
                            value={search}
                            onChange={(e) => {
                                setSearch(e.target.value);
                                setCurrentPage(1);
                            }}
                            placeholder="Search by name, code, phone..."
                            className={searchInput}
                        />
                    </div>
                </div>

                {isLoading ? (
                    <div className={tableCard}>
                        <div className={tableEmpty}>
                            <div className={tableSpinner} aria-label="Loading..." />
                            <p className="m-0">Loading mechanics...</p>
                        </div>
                    </div>
                ) : filtered.length === 0 ? (
                    <div className="rounded-3xl border-2 border-dashed border-edge bg-white py-20 text-center">
                        <Users size={40} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
                        <h3 className="m-0 font-display text-xl font-black text-ink">No mechanics found</h3>
                        <p className="mt-1 text-sm text-ink-muted">Add mechanics to assign them to shifts and requests.</p>
                    </div>
                ) : (
                    <div className={tableCard}>
                        <div className={tableScroll}>
                            <table className={dataTable}>
                                <thead>
                                    <tr>
                                        <th className={thCell}>Staff Code</th>
                                        <th className={thCell}>Full Name</th>
                                        <th className={thCell}>Phone Number</th>
                                        <th className={`${thCell} text-right`}>Actions</th>
                                    </tr>
                                </thead>
                                <tbody className="[&>tr:last-child>td]:border-b-0">
                                    {paginatedStaffs.map((staff) => (
                                        <tr key={staff.id} className={tableRow}>
                                            <td className={`${tdCell} font-semibold text-primary`}>{staff.staffCode}</td>
                                            <td className={`${tdCell} font-bold text-ink`}>{staff.fullName}</td>
                                            <td className={tdCell}>{staff.phone || '—'}</td>
                                            <td className={tdCell}>
                                                <div className="flex items-center justify-end gap-1.5">
                                                    <button
                                                        type="button"
                                                        onClick={() => handleEdit(staff)}
                                                        className={iconBtnEdit}
                                                        title="Edit Mechanic"
                                                    >
                                                        <Wrench size={15} />
                                                    </button>
                                                    {staff.status === 'BUSY' && (
                                                        <button
                                                            type="button"
                                                            onClick={() => handleResetStatus(staff.id)}
                                                            className={`bg-white border border-gray-200 text-gray-500 hover:bg-gray-100 hover:text-gray-700 h-8 w-8 inline-flex items-center justify-center rounded-lg shadow-sm transition ml-2`}
                                                            title="Reset Status to FREE"
                                                        >
                                                            <RefreshCw size={14} />
                                                        </button>
                                                    )}
                                                    <button
                                                        type="button"
                                                        onClick={() => handleDelete(staff.id, staff.fullName)}
                                                        className={`${iconBtnDelete} ml-2`}
                                                        title="Remove Mechanic"
                                                    >
                                                        <Trash2 size={15} />
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                        <div className="flex flex-col items-center justify-between gap-4 border-t border-edge px-4 py-4 sm:flex-row">
                            <span className="text-sm text-ink-muted">
                                Showing {pageStart + 1} to {Math.min(pageStart + ITEMS_PER_PAGE, filtered.length)} of {filtered.length} mechanics
                            </span>
                            <div className="flex items-center gap-2">
                                <button
                                    type="button"
                                    disabled={page === 1}
                                    onClick={() => setCurrentPage(Math.max(1, page - 1))}
                                    className="rounded-xl border border-edge bg-white px-3 py-1.5 text-sm font-semibold text-ink-muted hover:bg-primary-light hover:text-primary disabled:cursor-not-allowed disabled:opacity-50"
                                >
                                    Previous
                                </button>
                                <span className="px-2 text-sm font-semibold text-ink-muted">
                                    Page {page} of {totalPages}
                                </span>
                                <button
                                    type="button"
                                    disabled={page === totalPages}
                                    onClick={() => setCurrentPage(Math.min(totalPages, page + 1))}
                                    className="rounded-xl border border-edge bg-white px-3 py-1.5 text-sm font-semibold text-ink-muted hover:bg-primary-light hover:text-primary disabled:cursor-not-allowed disabled:opacity-50"
                                >
                                    Next
                                </button>
                            </div>
                        </div>
                    </div>
                )}
            </div>

            {isModalOpen && (
                <BranchStaffModal
                    staff={selectedStaff}
                    onClose={() => setIsModalOpen(false)}
                    onSuccess={() => { setIsModalOpen(false); fetchStaffs(); }}
                />
            )}
        </>
    );
};

export default BranchStaffManagement;

