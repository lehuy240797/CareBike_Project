import { useState, useEffect, useCallback } from 'react';
import toast from 'react-hot-toast';
import {
  Building2, Plus, Pencil, Trash2, MapPin, Phone, Search, LayoutGrid, List,
} from 'lucide-react';
import { getBranches, deleteBranch } from '../services/branchService';
import type { BranchRecord } from '../services/branchService';
import BranchModal from '../components/modals/BranchModal';
import ConfirmModal from '../components/modals/ConfirmModal';
import {
  badgeDanger, badgeNeutral, badgeSuccess, btnOutline, btnPrimary, dashTitle, eyebrow,
  iconBtnDelete, iconBtnEdit, tableCard, tableEmpty, dataTable,
  tableScroll, tableSpinner, tdCell, thCell, tableRow,
} from '../ui/styles';

// ─── Status badge config ──────────────────────────────────────────────────────

const STATUS_MAP: Record<string, { label: string; className: string }> = {
  ACTIVE: { label: 'Active', className: badgeSuccess },
  INACTIVE: { label: 'Suspended', className: badgeDanger },
};

const statusOf = (b: BranchRecord) =>
  STATUS_MAP[b.status?.toUpperCase()] ?? { label: b.status, className: badgeNeutral };

const initials = (name: string) =>
  name.split(' ').map((n) => n[0]).join('').slice(0, 2).toUpperCase();

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
  { id: 'ACTIVE', label: 'Active' },
  { id: 'INACTIVE', label: 'Suspended' },
];

// ─── Component ────────────────────────────────────────────────────────────────

const BranchManagement = () => {
  const [branches, setBranches] = useState<BranchRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState('');

  // ── Presentational UI state ──────────────────────────────────────────────
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [view, setView] = useState<'grid' | 'table'>('grid');

  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  // ── Modal state ────────────────────────────────────────────────────────────
  const [branchModal, setBranchModal] = useState<{
    open: boolean;
    mode: 'create' | 'edit';
    branch: BranchRecord | null;
  }>({ open: false, mode: 'create', branch: null });

  const [confirmModal, setConfirmModal] = useState<{
    open: boolean;
    branch: BranchRecord | null;
  }>({ open: false, branch: null });
  const [isDeleting, setIsDeleting] = useState(false);

  // ── Load data ──────────────────────────────────────────────────────────────
  const fetchBranches = useCallback(async () => {
    try {
      setIsLoading(true);
      setLoadError('');
      const data = await getBranches();
      setBranches(data);
    } catch {
      setLoadError('Could not load branches. Please try again.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchBranches(); }, [fetchBranches]);

  // ── Handlers ───────────────────────────────────────────────────────────────

  const openCreate = () =>
    setBranchModal({ open: true, mode: 'create', branch: null });

  const openEdit = (branch: BranchRecord) =>
    setBranchModal({ open: true, mode: 'edit', branch });

  const closeBranchModal = () =>
    setBranchModal({ open: false, mode: 'create', branch: null });

  // After create/edit success — update list in place without full reload
  const handleBranchSaved = (saved: BranchRecord) => {
    setBranches((prev) => {
      const idx = prev.findIndex((b) => b.id === saved.id);
      if (idx >= 0) {
        const next = [...prev];
        next[idx] = saved;
        return next;
      }
      return [...prev, saved];
    });
    closeBranchModal();
  };

  const openDeleteConfirm = (branch: BranchRecord) =>
    setConfirmModal({ open: true, branch });

  const closeDeleteConfirm = () =>
    setConfirmModal({ open: false, branch: null });

  const handleDeleteConfirm = async () => {
    if (!confirmModal.branch) return;
    setIsDeleting(true);
    try {
      await deleteBranch(confirmModal.branch.id);
      setBranches((prev) => prev.filter((b) => b.id !== confirmModal.branch!.id));
      toast.success('Branch deleted successfully');
      closeDeleteConfirm();
    } catch (error: any) {
      toast.error(error?.response?.data?.message || 'Unable to delete branch. It may have associated data.');
    } finally {
      setIsDeleting(false);
    }
  };

  // ── Derived view-model ─────────────────────────────────────────────────────
  const total = branches.length;
  const activeCount = branches.filter((b) => b.status?.toUpperCase() === 'ACTIVE').length;
  const inactiveCount = branches.filter((b) => b.status?.toUpperCase() === 'INACTIVE').length;
  const assignedCount = branches.filter((b) => b.manager).length;

  const kpis = [
    { label: 'Total branches', val: total, color: '#f97316', badge: 'system' },
    { label: 'Active', val: activeCount, color: '#16a34a', badge: 'active' },
    { label: 'Suspended', val: inactiveCount, color: '#dc2626', badge: 'suspended' },
    { label: 'Managed', val: assignedCount, color: '#6366f1', badge: 'manager' },
  ];

  const filtered = branches.filter((b) => {
    const matchSearch =
      !search ||
      [b.name, b.manager?.fullName, b.manager?.email, b.address].some((v) =>
        v?.toLowerCase().includes(search.toLowerCase()),
      );
    const matchStatus = statusFilter === 'All' || b.status?.toUpperCase() === statusFilter;
    return matchSearch && matchStatus;
  });

  const totalPages = Math.ceil(filtered.length / itemsPerPage) || 1;
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginated = filtered.slice(startIndex, startIndex + itemsPerPage);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, statusFilter, view]);

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <>
      <div className="mx-auto max-w-[80rem]">
        {/* Header */}
        <div className="mb-8 flex items-start justify-between gap-4 animate-fade-up">
          <div>
            <p className={eyebrow}>Management</p>
            <h1 className={`${dashTitle} mt-1`}>Branch Management</h1>
            <p className="mt-1.5 font-pop text-sm text-ink-muted">
              {total} branches in the system
            </p>
          </div>
          <button type="button" className={btnPrimary} onClick={openCreate}>
            <Plus size={16} aria-hidden="true" /> Add branch
          </button>
        </div>

        {isLoading ? (
          <div className={tableCard}>
            <div className={tableEmpty}>
              <div className={tableSpinner} aria-label="Loading..." />
              <p className="m-0">Loading data...</p>
            </div>
          </div>
        ) : loadError ? (
          <div className={tableCard}>
            <div className={`${tableEmpty} text-red-600`}>
              <p className="m-0">{loadError}</p>
              <button type="button" className={btnOutline} onClick={fetchBranches}>Retry</button>
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
                  placeholder="Search by name, manager, address..."
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
                <Building2 size={40} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
                <h3 className="m-0 font-display text-xl font-black text-ink">No branches found</h3>
                <p className="mt-1 text-sm text-ink-muted">Try changing the filters or add a new branch.</p>
              </div>
            ) : view === 'grid' ? (
              /* GRID VIEW */
              <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-3">
                {paginated.map((branch) => {
                  const status = statusOf(branch);
                  return (
                    <div
                      key={branch.id}
                      className="group rounded-3xl border border-edge bg-white p-6 transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_0_22px_rgba(249,115,22,0.20)]"
                    >
                      <div className="mb-5 flex items-start justify-between">
                        <div className="flex items-center gap-3">
                          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-primary text-lg font-black text-white">
                            {branch.name?.[0]?.toUpperCase() ?? 'B'}
                          </div>
                          <div>
                            <h4 className="m-0 font-display text-sm font-black leading-tight text-ink">{branch.name}</h4>
                            <p className="m-0 mt-0.5 text-xs text-ink-muted">#{branch.id}</p>
                          </div>
                        </div>
                        <span className={status.className}>{status.label}</span>
                      </div>

                      <div className="mb-5 space-y-2 text-sm">
                        <div className="flex items-center gap-2 text-ink-muted">
                          <MapPin size={14} className="shrink-0" aria-hidden="true" />
                          <span className="truncate">{branch.address ?? '—'}</span>
                        </div>
                        <div className="flex items-center gap-2 text-ink-muted">
                          <Phone size={14} className="shrink-0" aria-hidden="true" />
                          <span>{branch.phone ?? '—'}</span>
                        </div>
                      </div>

                      <div className="flex items-center justify-between border-t border-edge pt-4">
                        <div className="flex min-w-0 items-center gap-2">
                          {branch.manager ? (
                            <>
                              <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary-light text-xs font-bold text-primary">
                                {initials(branch.manager.fullName || branch.manager.email || 'MG')}
                              </div>
                              <span className="truncate text-xs font-medium text-ink-muted">
                                {branch.manager.fullName || branch.manager.email}
                              </span>
                            </>
                          ) : (
                            <span className="text-xs text-ink-muted">Unassigned</span>
                          )}
                        </div>
                        <div className="flex shrink-0 gap-1.5">
                          <button type="button" className={iconBtnEdit} title="Edit" onClick={() => openEdit(branch)}>
                            <Pencil size={15} />
                          </button>
                          <button type="button" className={iconBtnDelete} title="Delete branch" onClick={() => openDeleteConfirm(branch)}>
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}

                {/* Add card */}
                <button
                  type="button"
                  onClick={openCreate}
                  className="group flex min-h-64 flex-col items-center justify-center rounded-3xl border-2 border-dashed border-edge bg-white p-6 transition-all duration-300 hover:border-primary hover:bg-primary-light"
                >
                  <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary-light text-primary transition-all group-hover:bg-primary-muted">
                    <Plus size={28} />
                  </div>
                  <p className="m-0 text-sm font-bold text-ink">Add new branch</p>
                  <p className="m-0 mt-1 text-xs text-ink-muted">Click to configure</p>
                </button>
              </div>
            ) : (
              /* TABLE VIEW */
              <div className={tableCard}>
                <div className={tableScroll}>
                  <table className={dataTable}>
                    <thead>
                      <tr>
                        <th className={thCell}>#</th>
                        <th className={thCell}>Branch name</th>
                        <th className={thCell}>Address</th>
                        <th className={thCell}>Phone</th>
                        <th className={thCell}>Manager</th>
                        <th className={thCell}>Status</th>
                        <th className={`${thCell} text-right`}>Actions</th>
                      </tr>
                    </thead>
                    <tbody className="[&>tr:last-child>td]:border-b-0">
                      {paginated.map((branch) => {
                        const status = statusOf(branch);
                        return (
                          <tr key={branch.id} className={tableRow}>
                            <td className={`${tdCell} text-sm text-ink-muted`}>{branch.id}</td>
                            <td className={`${tdCell} font-semibold`}>{branch.name}</td>
                            <td className={tdCell}>{branch.address ?? '—'}</td>
                            <td className={tdCell}>{branch.phone ?? '—'}</td>
                            <td className={tdCell}>
                              {branch.manager ? (
                                <span className="font-medium">
                                  {branch.manager.fullName || branch.manager.email || `ID: ${branch.manager.id}`}
                                </span>
                              ) : (
                                <span className="text-sm text-ink-muted">None</span>
                              )}
                            </td>
                            <td className={tdCell}><span className={status.className}>{status.label}</span></td>
                            <td className={tdCell}>
                              <div className="flex items-center justify-end gap-1.5">
                                <button type="button" className={iconBtnEdit} title="Edit" onClick={() => openEdit(branch)}>
                                  <Pencil size={15} />
                                </button>
                                <button type="button" className={iconBtnDelete} title="Delete branch" onClick={() => openDeleteConfirm(branch)}>
                                  <Trash2 size={15} />
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
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

      {/* ── Modals ─────────────────────────────────────────────────────────── */}

      {branchModal.open && (
        <BranchModal
          mode={branchModal.mode}
          branch={branchModal.branch}
          onClose={closeBranchModal}
          onSuccess={handleBranchSaved}
        />
      )}

      {confirmModal.open && confirmModal.branch && (
        <ConfirmModal
          title="Delete branch"
          message={`Are you sure you want to delete the branch "${confirmModal.branch.name}"? This action cannot be undone.`}
          confirmLabel="Delete"
          isDestructive
          isLoading={isDeleting}
          onConfirm={handleDeleteConfirm}
          onClose={closeDeleteConfirm}
        />
      )}
    </>
  );
};

export default BranchManagement;
