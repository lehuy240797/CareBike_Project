import { useState, useEffect, useCallback } from 'react';
import { UserCog, Plus, Lock, Unlock, Trash2, Search, LayoutGrid, List, Mail, Phone } from 'lucide-react';
import { apiGetAllUsers, apiToggleUserStatus, apiDeleteUser } from '../services/userService';
import type { UserRecord } from '../services/userService';
import StaffModal from '../components/modals/StaffModal';
import toast from 'react-hot-toast';
import {
    badgeDanger, badgeSuccess, btnPrimary, dashTitle, eyebrow, iconBtnDelete, iconBtnEdit,
    tableCard, tableEmpty, dataTable, tableScroll, tableSpinner, tdCell, thCell, tableRow,
} from '../ui/styles';

const initials = (name: string) =>
    (name || '?').split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase();

// ─── Filter UI primitives ──────────────────────────────────────────────────────

const searchInput =
    'w-full rounded-2xl border border-edge bg-primary-light/40 py-2.5 pl-10 pr-4 text-sm outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary/20';
const pill = (active: boolean) =>
    `rounded-full px-4 py-2 text-sm font-semibold transition-all ${active ? 'bg-primary text-white shadow' : 'bg-primary-light text-primary-deep hover:bg-primary-muted'
    }`;
const viewBtn = (active: boolean) =>
    `flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-semibold transition-all ${active ? 'bg-primary text-white shadow' : 'text-primary-deep hover:bg-primary-muted'
    }`;

const STATUS_FILTERS = [
    { id: 'All', label: 'All' },
    { id: 'active', label: 'Active' },
    { id: 'locked', label: 'Locked' },
];

const StaffManagement = () => {
    const [staffs, setStaffs] = useState<UserRecord[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [isModalOpen, setIsModalOpen] = useState(false);

    // ── Presentational UI state ────────────────────────────────────────────
    const [search, setSearch] = useState('');
    const [statusFilter, setStatusFilter] = useState('All');
    const [view, setView] = useState<'grid' | 'table'>('grid');

    const [currentPage, setCurrentPage] = useState(1);
    const itemsPerPage = 10;

    const fetchStaffs = useCallback(async () => {
        try {
            setIsLoading(true);
            const data = await apiGetAllUsers();
            // Keep only users whose role is BRANCH
            const branchManagers = data.filter(u => u.role?.roleName === 'BRANCH');
            setStaffs(branchManagers);
        } catch (error) {
            console.error("Failed to load staff list", error);
        } finally {
            setIsLoading(false);
        }
    }, []);

    useEffect(() => { fetchStaffs(); }, [fetchStaffs]);

    const handleToggleStatus = async (id: number) => {
        try {
            await apiToggleUserStatus(id);
            fetchStaffs(); // Refresh the list after lock/unlock
        } catch (error) {
            toast.error("Could not change this account's status.");
        }
    };

    const handleDeleteStaff = async (id: number, name: string) => {
        const confirmDelete = window.confirm(`Are you sure you want to PERMANENTLY DELETE the account of "${name}"?\nThis will also wipe its data on Firebase.`);
        if (!confirmDelete) return;

        try {
            await apiDeleteUser(id);
            toast.success("Account deleted successfully!");
            fetchStaffs(); // Reload the list after deleting
        } catch (error: any) {
            // Surface the backend's block message on screen (e.g. still managing a branch)
            const msg = error?.response?.data?.message ?? "Could not delete this account.";
            toast.error(msg);
        }
    };

    // ── Derived view-model ───────────────────────────────────────────────────
    const total = staffs.length;
    const activeCount = staffs.filter((s) => s.isActive).length;
    const lockedCount = staffs.filter((s) => !s.isActive).length;
    const activeRate = total ? Math.round((activeCount / total) * 100) : 0;

    const kpis = [
        { label: 'Total staff', val: total, color: '#f97316', badge: 'staff' },
        { label: 'Active', val: activeCount, color: '#16a34a', badge: 'active' },
        { label: 'Locked', val: lockedCount, color: '#dc2626', badge: 'locked' },
        { label: 'Active rate', val: `${activeRate}%`, color: '#6366f1', badge: 'rate' },
    ];

    const filtered = staffs.filter((s) => {
        const matchSearch =
            !search ||
            [s.fullName, s.email, s.phone, String(s.id)].some((v) =>
                v?.toLowerCase().includes(search.toLowerCase()),
            );
        const isActive = !!s.isActive;
        const matchStatus =
            statusFilter === 'All' ||
            (statusFilter === 'active' && isActive) ||
            (statusFilter === 'locked' && !isActive);
        return matchSearch && matchStatus;
    });

    const totalPages = Math.ceil(filtered.length / itemsPerPage) || 1;
    const startIndex = (currentPage - 1) * itemsPerPage;
    const paginated = filtered.slice(startIndex, startIndex + itemsPerPage);

    useEffect(() => {
        setCurrentPage(1);
    }, [search, statusFilter, view]);

    return (
        <>
            <div className="mx-auto max-w-[80rem]">
                {/* Header */}
                <div className="mb-8 flex items-start justify-between gap-4 animate-fade-up">
                    <div>
                        <p className={eyebrow}>Staff Management</p>
                        <h1 className={`${dashTitle} mt-1`}>Staff</h1>
                        <p className="mt-1.5 font-pop text-sm text-ink-muted">
                            Manage branch manager accounts and their status
                        </p>
                    </div>
                    <button type="button" className={btnPrimary} onClick={() => setIsModalOpen(true)}>
                        <Plus size={16} aria-hidden="true" /> New account
                    </button>
                </div>

                {isLoading ? (
                    <div className={tableCard}>
                        <div className={tableEmpty}>
                            <div className={tableSpinner} aria-label="Loading..." />
                            <p className="m-0">Loading data...</p>
                        </div>
                    </div>
                ) : (
                    <>
                        {/* KPI cards */}
                        <div className="mb-8 grid grid-cols-2 gap-4 lg:grid-cols-4">
                            {kpis.map((k) => (
                                <div
                                    key={k.label}
                                    className="rounded-3xl border border-edge bg-white p-6 transition-all duration-300 hover:-translate-y-0.5 hover:border-primary hover:shadow-[0_0_22px_rgba(249,115,22,0.22)]"
                                >
                                    <div className="mb-2 flex items-center gap-1.5">
                                        <span className="h-2 w-2 rounded-full" style={{ background: k.color }} />
                                        <p className="text-xs text-ink-muted">{k.label}</p>
                                    </div>
                                    <p className="mb-3 font-display text-4xl font-black tabular-nums" style={{ color: k.color }}>
                                        {k.val}
                                    </p>
                                    <span className="inline-flex rounded-full bg-primary-light px-2.5 py-0.5 text-xs font-semibold text-primary">
                                        {k.badge}
                                    </span>
                                </div>
                            ))}
                        </div>

                        {/* Filter bar */}
                        <div className="mb-6 flex flex-wrap items-center gap-4 rounded-3xl border border-edge bg-white p-4 shadow-sm">
                            <div className="relative min-w-48 flex-1">
                                <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted" aria-hidden="true" />
                                <input
                                    value={search}
                                    onChange={(e) => setSearch(e.target.value)}
                                    placeholder="Search by name, email, phone..."
                                    className={searchInput}
                                />
                            </div>
                            <div className="flex flex-wrap gap-2">
                                {STATUS_FILTERS.map((s) => (
                                    <button key={s.id} type="button" onClick={() => setStatusFilter(s.id)} className={pill(statusFilter === s.id)}>
                                        {s.label}
                                    </button>
                                ))}
                            </div>
                            <div className="flex items-center gap-1 rounded-2xl border border-edge bg-primary-light/50 p-1">
                                <button type="button" onClick={() => setView('grid')} className={viewBtn(view === 'grid')}>
                                    <LayoutGrid size={14} /> Grid
                                </button>
                                <button type="button" onClick={() => setView('table')} className={viewBtn(view === 'table')}>
                                    <List size={14} /> Table
                                </button>
                            </div>
                        </div>

                        {/* Empty state */}
                        {filtered.length === 0 ? (
                            <div className="rounded-3xl border-2 border-dashed border-edge bg-white py-20 text-center">
                                <UserCog size={40} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
                                <h3 className="m-0 font-display text-xl font-black text-ink">No staff found</h3>
                                <p className="mt-1 text-sm text-ink-muted">Try changing the filters or create a new manager account.</p>
                            </div>
                        ) : view === 'grid' ? (
                            /* GRID VIEW */
                            <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-3">
                                {paginated.map((staff) => {
                                    const isActive = !!staff.isActive;
                                    return (
                                        <div
                                            key={staff.id}
                                            className="group rounded-3xl border border-edge bg-white p-6 transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_10px_35px_rgba(249,115,22,0.12)]"
                                        >
                                            {/* Top */}
                                            <div className="mb-5 flex items-start justify-between">
                                                <div className="flex min-w-0 items-center gap-3">
                                                    <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-primary text-xl font-black text-white shadow-md">
                                                        {initials(staff.fullName || staff.email)}
                                                    </div>
                                                    <div className="min-w-0">
                                                        <h3 className="m-0 truncate font-display font-black leading-tight text-ink">
                                                            {staff.fullName || '—'}
                                                        </h3>
                                                        <p className="m-0 mt-0.5 text-xs text-ink-muted">Branch Manager</p>
                                                        <p className="m-0 mt-0.5 text-xs text-ink-muted/70">#{staff.id}</p>
                                                    </div>
                                                </div>
                                                <span className={isActive ? badgeSuccess : badgeDanger}>
                                                    {isActive ? 'Active' : 'Locked'}
                                                </span>
                                            </div>

                                            {/* Info */}
                                            <div className="mb-5 space-y-2.5 text-sm">
                                                <div className="flex items-center gap-2 text-ink-muted">
                                                    <Mail size={14} className="shrink-0" aria-hidden="true" />
                                                    <span className="truncate">{staff.email}</span>
                                                </div>
                                                <div className="flex items-center gap-2 text-ink-muted">
                                                    <Phone size={14} className="shrink-0" aria-hidden="true" />
                                                    <span>{staff.phone || '—'}</span>
                                                </div>
                                            </div>

                                            {/* Actions */}
                                            <div className="flex gap-2.5 border-t border-edge pt-4">
                                                <button
                                                    type="button"
                                                    onClick={() => handleToggleStatus(staff.id)}
                                                    className={`flex flex-1 items-center justify-center gap-1.5 rounded-2xl py-2.5 text-sm font-semibold transition-all ${isActive
                                                            ? 'bg-red-50 text-red-600 hover:bg-red-500 hover:text-white'
                                                            : 'bg-green-50 text-green-700 hover:bg-green-500 hover:text-white'
                                                        }`}
                                                    title={isActive ? 'Lock account' : 'Unlock account'}
                                                >
                                                    {isActive ? <Lock size={15} /> : <Unlock size={15} />}
                                                    {isActive ? 'Lock' : 'Unlock'}
                                                </button>
                                                <button
                                                    type="button"
                                                    onClick={() => handleDeleteStaff(staff.id, staff.fullName || staff.email)}
                                                    className="flex items-center justify-center rounded-2xl bg-red-50 px-3.5 py-2.5 text-sm font-semibold text-red-500 transition-all hover:bg-red-500 hover:text-white"
                                                    title="Delete permanently"
                                                >
                                                    <Trash2 size={15} />
                                                </button>
                                            </div>
                                        </div>
                                    );
                                })}

                                {/* Add card */}
                                <button
                                    type="button"
                                    onClick={() => setIsModalOpen(true)}
                                    className="group flex min-h-64 flex-col items-center justify-center rounded-3xl border-2 border-dashed border-edge bg-white p-6 transition-all duration-300 hover:border-primary hover:bg-primary-light"
                                >
                                    <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary-light text-primary transition-all group-hover:bg-primary-muted">
                                        <Plus size={28} />
                                    </div>
                                    <p className="m-0 text-sm font-bold text-ink">New account</p>
                                    <p className="m-0 mt-1 text-xs text-ink-muted">Click to add a manager</p>
                                </button>
                            </div>
                        ) : (
                            /* TABLE VIEW */
                            <div className={tableCard}>
                                <div className={tableScroll}>
                                    <table className={dataTable}>
                                        <thead>
                                            <tr>
                                                <th className={thCell}>#ID</th>
                                                <th className={thCell}>Full name</th>
                                                <th className={thCell}>Login email</th>
                                                <th className={thCell}>Phone</th>
                                                <th className={thCell}>Status</th>
                                                <th className={`${thCell} text-right`}>Lock / Unlock</th>
                                            </tr>
                                        </thead>
                                        <tbody className="[&>tr:last-child>td]:border-b-0">
                                            {paginated.map((staff) => (
                                                <tr key={staff.id} className={tableRow}>
                                                    <td className={`${tdCell} text-sm text-ink-muted`}>{staff.id}</td>
                                                    <td className={`${tdCell} font-medium`}>{staff.fullName || '—'}</td>
                                                    <td className={`${tdCell} font-semibold`}>{staff.email}</td>
                                                    <td className={tdCell}>{staff.phone || '—'}</td>
                                                    <td className={tdCell}>
                                                        <span className={staff.isActive ? badgeSuccess : badgeDanger}>
                                                            {staff.isActive ? 'Active' : 'Locked'}
                                                        </span>
                                                    </td>
                                                    <td className={tdCell}>
                                                        <div className="flex items-center justify-end gap-1.5">
                                                            <button
                                                                type="button"
                                                                onClick={() => handleToggleStatus(staff.id)}
                                                                className={staff.isActive ? iconBtnDelete : iconBtnEdit}
                                                                title={staff.isActive ? "Lock account" : "Unlock account"}
                                                            >
                                                                {staff.isActive ? <Lock size={15} /> : <Unlock size={15} />}
                                                            </button>
                                                            <button
                                                                type="button"
                                                                onClick={() => handleDeleteStaff(staff.id, staff.fullName || staff.email)}
                                                                className={`${iconBtnDelete} ml-2`}
                                                                title="Delete permanently"
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
                            </div>
                        )}

                        {/* Pagination Controls */}
                        {filtered.length > 0 && (
                            <div className="mt-6 border-t border-edge pt-4 flex flex-col sm:flex-row items-center justify-between gap-4">
                                <span className="text-sm text-ink-muted">
                                    Showing {Math.min((currentPage - 1) * itemsPerPage + 1, filtered.length)} to {Math.min(currentPage * itemsPerPage, filtered.length)} of {filtered.length} entries
                                </span>
                                <div className="flex gap-2">
                                    <button type="button" disabled={currentPage === 1} onClick={() => setCurrentPage(p => p - 1)} className="rounded-xl border border-edge bg-white px-3 py-1.5 text-sm font-semibold text-ink-muted hover:bg-primary-light hover:text-primary disabled:opacity-50">Prev</button>
                                    <span className="flex items-center px-2 text-sm font-semibold text-ink-muted">Page {currentPage} of {totalPages}</span>
                                    <button type="button" disabled={currentPage === totalPages} onClick={() => setCurrentPage(p => p + 1)} className="rounded-xl border border-edge bg-white px-3 py-1.5 text-sm font-semibold text-ink-muted hover:bg-primary-light hover:text-primary disabled:opacity-50">Next</button>
                                </div>
                            </div>
                        )}
                    </>
                )}
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
