import { useState, useEffect, useCallback } from 'react';
import { Users, Lock, Unlock, Bike, Wrench, Star, Search, LayoutGrid, List } from 'lucide-react';
import { getCustomers } from '../services/customerService';
import { apiToggleUserStatus } from '../services/userService';
import { getAllProfiles } from '../services/customerProfileService';
import type { UserRecord } from '../services/userService';
import type { CustomerProfile, MemberTier } from '../types/api';
import VehicleModal from '../components/modals/VehicleModal';
import MaintenanceModal from '../components/modals/MaintenanceModal';
import {
  badgeDanger, badgeGold, badgeNeutral, badgePlatinum, badgeSilver, badgeSuccess,
  btnOutline, dashTitle, eyebrow, iconBtnDelete, iconBtnMaintenance, iconBtnUnlock, iconBtnVehicle,
  loyaltyPoints, tableCard, tableEmpty, dataTable, tableScroll, tableSpinner,
  tdCell, thCell, tableRow,
} from '../ui/styles';

// ─── Tier badge config ────────────────────────────────────────────────────────

const TIER_CONFIG: Record<MemberTier, { label: string; className: string }> = {
  STANDARD: { label: 'Standard', className: badgeNeutral },
  SILVER: { label: 'Silver', className: badgeSilver },
  GOLD: { label: 'Gold', className: badgeGold },
  PLATINUM: { label: 'Platinum', className: badgePlatinum },
};

// ─── Sub-types ────────────────────────────────────────────────────────────────

type ModalState =
  | { type: 'vehicle'; customer: UserRecord }
  | { type: 'maintenance'; customer: UserRecord }
  | null;

// ─── Helpers ──────────────────────────────────────────────────────────────────

const formatDate = (dateStr: string) => {
  try {
    return new Date(dateStr).toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
  } catch { return '—'; }
};

const formatPoints = (pts: number) =>
  new Intl.NumberFormat('en-US').format(pts) + ' pts';

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
const cardActionBlue =
  'flex flex-1 items-center justify-center gap-1.5 rounded-2xl bg-blue-50 py-2.5 text-sm font-semibold text-blue-600 transition-all hover:bg-blue-100';
const cardActionAmber =
  'flex flex-1 items-center justify-center gap-1.5 rounded-2xl bg-amber-50 py-2.5 text-sm font-semibold text-amber-600 transition-all hover:bg-amber-100';

const STATUS_FILTERS = [
  { id: 'All', label: 'All' },
  { id: 'active', label: 'Active' },
  { id: 'locked', label: 'Locked' },
];

// ─── Component ────────────────────────────────────────────────────────────────

const CustomerManagement = () => {
  const [customers, setCustomers] = useState<UserRecord[]>([]);
  const [profiles, setProfiles] = useState<Map<number, CustomerProfile>>(new Map());
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [modal, setModal] = useState<ModalState>(null);
  const [togglingId, setTogglingId] = useState<number | null>(null);

  // ── Presentational UI state ──────────────────────────────────────────────
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [view, setView] = useState<'grid' | 'table'>('grid');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    setCurrentPage(1);
  }, [search, statusFilter]);

  // ── Load customers + loyalty profiles in parallel ─────────────────────────
  const fetchAll = useCallback(async () => {
    setIsLoading(true);
    setLoadError('');
    try {
      const [allUsers, allProfiles] = await Promise.all([
        getCustomers(),
        getAllProfiles().catch(() => [] as CustomerProfile[]), // profiles are optional
      ]);

      // Filter to CUSTOMER role only
      const onlyCustomers = allUsers.filter(
        (u) => u.role?.roleName?.toUpperCase() === 'CUSTOMER',
      );
      setCustomers(onlyCustomers);

      // Build a map of userId → profile for O(1) lookup in the table
      const profileMap = new Map<number, CustomerProfile>();
      allProfiles.forEach((p) => profileMap.set(p.user.id, p));
      setProfiles(profileMap);
    } catch {
      setLoadError('Could not load customers. Please try again.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  // ── Toggle lock/unlock ─────────────────────────────────────────────────────
  const handleToggleStatus = async (customer: UserRecord) => {
    setTogglingId(customer.id);
    try {
      const updated = await apiToggleUserStatus(customer.id);
      setCustomers((prev) => prev.map((c) => (c.id === updated.id ? updated : c)));
    } catch {
      /* silently revert */
    } finally {
      setTogglingId(null);
    }
  };

  // ── Derived view-model ─────────────────────────────────────────────────────
  const total = customers.length;
  const activeCount = customers.filter((c) => c.isActive !== false).length;
  const lockedCount = customers.filter((c) => c.isActive === false).length;
  const vipCount = customers.filter((c) => {
    const t = profiles.get(c.id)?.memberTier;
    return t === 'GOLD' || t === 'PLATINUM';
  }).length;

  const kpis = [
    { label: 'Total customers', val: total, color: '#f97316', badge: 'accounts' },
    { label: 'Active', val: activeCount, color: '#16a34a', badge: 'active' },
    { label: 'Locked', val: lockedCount, color: '#dc2626', badge: 'locked' },
    { label: 'High tier', val: vipCount, color: '#f59e0b', badge: 'VIP' },
  ];

  const filtered = customers.filter((c) => {
    const matchSearch =
      !search ||
      [c.fullName, c.email, c.username, String(c.id)].some((v) =>
        v?.toLowerCase().includes(search.toLowerCase()),
      );
    const isActive = c.isActive !== false;
    const matchStatus =
      statusFilter === 'All' ||
      (statusFilter === 'active' && isActive) ||
      (statusFilter === 'locked' && !isActive);
    return matchSearch && matchStatus;
  });

  const totalPages = Math.ceil(filtered.length / itemsPerPage) || 1;
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <>
      <div className="mx-auto max-w-[80rem]">
        {/* Header */}
        <div className="mb-8 animate-fade-up">
          <p className={eyebrow}>Customer Management</p>
          <h1 className={`${dashTitle} mt-1`}>Customers</h1>
          <p className="mt-1.5 font-pop text-sm text-ink-muted">
            Manage accounts, vehicle profiles and maintenance history
          </p>
        </div>

        {isLoading ? (
          <div className={tableCard}>
            <div className={tableEmpty}>
              <div className={tableSpinner} aria-label="Loading..." />
              <p className="m-0">Loading customers...</p>
            </div>
          </div>
        ) : loadError ? (
          <div className={tableCard}>
            <div className={`${tableEmpty} text-red-600`}>
              <p className="m-0">{loadError}</p>
              <button type="button" className={btnOutline} onClick={fetchAll}>Retry</button>
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
                  placeholder="Search by name, email, username..."
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
                <Users size={40} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
                <h3 className="m-0 font-display text-xl font-black text-ink">No customers found</h3>
                <p className="mt-1 text-sm text-ink-muted">Try changing the filters or your search.</p>
              </div>
            ) : view === 'grid' ? (
              /* GRID VIEW */
              <>
                <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-3">
                  {paginated.map((customer) => {
                  const isActive = customer.isActive !== false;
                  const isToggling = togglingId === customer.id;
                  const profile = profiles.get(customer.id);
                  const tier = (profile?.memberTier as MemberTier) ?? 'STANDARD';
                  const tierCfg = TIER_CONFIG[tier];

                  return (
                    <div
                      key={customer.id}
                      className="group rounded-3xl border border-edge bg-white p-6 transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_10px_35px_rgba(249,115,22,0.12)]"
                    >
                      {/* Top */}
                      <div className="mb-5 flex items-start justify-between">
                        <div className="flex min-w-0 items-center gap-3">
                          <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-primary text-xl font-black text-white shadow-md">
                            {initials(customer.fullName || customer.username)}
                          </div>
                          <div className="min-w-0">
                            <h3 className="m-0 truncate font-display font-black leading-tight text-ink">
                              {customer.fullName || customer.username}
                            </h3>
                            <p className="m-0 mt-0.5 truncate text-xs text-ink-muted">{customer.email}</p>
                            <p className="m-0 mt-0.5 text-xs text-ink-muted/70">#{customer.id}</p>
                          </div>
                        </div>
                        <span className={isActive ? badgeSuccess : badgeDanger}>
                          {isActive ? 'Active' : 'Locked'}
                        </span>
                      </div>

                      {/* Tier + points */}
                      <div className="mb-5 grid grid-cols-2 gap-2.5">
                        <div className="rounded-2xl border border-edge bg-primary-light/50 p-3 text-center">
                          <span className={tierCfg.className}>
                            {tier !== 'STANDARD' && <Star size={10} className="mr-1 align-middle" />}
                            {tierCfg.label}
                          </span>
                          <p className="mt-1.5 text-xs text-ink-muted">Membership tier</p>
                        </div>
                        <div className="rounded-2xl border border-edge bg-primary-light/50 p-3 text-center">
                          <p className={`${loyaltyPoints} text-base`}>
                            {profile ? new Intl.NumberFormat('en-US').format(profile.accumulatedPoints) : '—'}
                          </p>
                          <p className="mt-0.5 text-xs text-ink-muted">Loyalty points</p>
                        </div>
                      </div>

                      {/* Info */}
                      <div className="mb-5 space-y-2.5 text-xs">
                        <div className="flex items-center justify-between">
                          <span className="text-ink-muted">Phone</span>
                          <span className="font-semibold text-ink">{customer.phone || '—'}</span>
                        </div>
                        <div className="flex items-center justify-between">
                          <span className="text-ink-muted">Username</span>
                          <span className="max-w-[8rem] truncate font-semibold text-ink">{customer.username}</span>
                        </div>
                        <div className="flex items-center justify-between">
                          <span className="text-ink-muted">Registered</span>
                          <span className="font-semibold text-ink">{formatDate(customer.createdAt)}</span>
                        </div>
                      </div>

                      {/* Actions */}
                      <div className="flex gap-2.5 border-t border-edge pt-4">
                        <button type="button" className={cardActionBlue} title="Vehicle profile" onClick={() => setModal({ type: 'vehicle', customer })}>
                          <Bike size={15} /> Vehicle
                        </button>
                        <button type="button" className={cardActionAmber} title="Maintenance history" onClick={() => setModal({ type: 'maintenance', customer })}>
                          <Wrench size={15} /> Maintenance
                        </button>
                        <button
                          type="button"
                          className={`flex items-center justify-center rounded-2xl px-3.5 py-2.5 text-sm font-semibold transition-all ${isActive
                              ? 'bg-red-50 text-red-600 hover:bg-red-500 hover:text-white'
                              : 'bg-green-50 text-green-700 hover:bg-green-500 hover:text-white'
                            }`}
                          title={isActive ? 'Lock account' : 'Unlock account'}
                          onClick={() => handleToggleStatus(customer)}
                          disabled={isToggling}
                          aria-busy={isToggling}
                        >
                          {isToggling
                            ? <span className="h-4 w-4 animate-spin-fast rounded-full border-2 border-current/30 border-t-current" />
                            : isActive ? <Lock size={15} /> : <Unlock size={15} />
                          }
                        </button>
                      </div>
                    </div>
                  );
                })}
                </div>
                {/* Pagination Controls */}
                <div className="mt-6 flex items-center justify-between">
                  <span className="text-sm text-ink-muted">
                    Showing {Math.min((currentPage - 1) * itemsPerPage + 1, filtered.length)} to {Math.min(currentPage * itemsPerPage, filtered.length)} of {filtered.length} entries
                  </span>
                  <div className="flex gap-2">
                    <button type="button" disabled={currentPage === 1} onClick={() => setCurrentPage(p => p - 1)} className="rounded-xl border border-edge bg-white px-3 py-1.5 text-sm font-semibold text-ink-muted hover:bg-primary-light hover:text-primary disabled:opacity-50">Prev</button>
                    <span className="flex items-center px-2 text-sm font-semibold text-ink-muted">Page {currentPage} of {totalPages}</span>
                    <button type="button" disabled={currentPage === totalPages} onClick={() => setCurrentPage(p => p + 1)} className="rounded-xl border border-edge bg-white px-3 py-1.5 text-sm font-semibold text-ink-muted hover:bg-primary-light hover:text-primary disabled:opacity-50">Next</button>
                  </div>
                </div>
              </>
            ) : (
              /* TABLE VIEW */
              <div className={tableCard}>
                <div className={tableScroll}>
                  <table className={dataTable}>
                    <thead>
                      <tr>
                        <th className={thCell}>#</th>
                        <th className={thCell}>Full name</th>
                        <th className={thCell}>Username / Email</th>
                        <th className={thCell}>Registered</th>
                        <th className={thCell}>Tier</th>
                        <th className={thCell}>Points</th>
                        <th className={thCell}>Status</th>
                        <th className={`${thCell} text-right`}>Actions</th>
                      </tr>
                    </thead>
                    <tbody className="[&>tr:last-child>td]:border-b-0">
                      {paginated.map((customer) => {
                        const isActive = customer.isActive !== false;
                        const isToggling = togglingId === customer.id;
                        const profile = profiles.get(customer.id);
                        const tier = (profile?.memberTier as MemberTier) ?? 'STANDARD';
                        const tierCfg = TIER_CONFIG[tier];

                        return (
                          <tr key={customer.id} className={tableRow}>
                            <td className={`${tdCell} text-sm text-ink-muted`}>#{customer.id}</td>
                            <td className={tdCell}>
                              <div className="font-semibold">{customer.fullName || '—'}</div>
                              <div className="mt-0.5 text-[0.8125rem] text-ink-muted">{customer.phone || '—'}</div>
                            </td>
                            <td className={tdCell}>
                              <div>{customer.username}</div>
                              <div className="mt-0.5 text-[0.8125rem] text-ink-muted">{customer.email}</div>
                            </td>
                            <td className={tdCell}>{formatDate(customer.createdAt)}</td>
                            <td className={tdCell}>
                              <span className={tierCfg.className}>
                                {tier !== 'STANDARD' && <Star size={10} className="mr-1 align-middle" />}
                                {tierCfg.label}
                              </span>
                            </td>
                            <td className={tdCell}>
                              {profile
                                ? <span className={loyaltyPoints}>{formatPoints(profile.accumulatedPoints)}</span>
                                : <span className="text-sm text-ink-muted">—</span>
                              }
                            </td>
                            <td className={tdCell}>
                              <span className={isActive ? badgeSuccess : badgeDanger}>
                                {isActive ? 'Active' : 'Locked'}
                              </span>
                            </td>
                            <td className={tdCell}>
                              <div className="flex items-center justify-end gap-1.5">
                                <button
                                  type="button"
                                  className={isActive ? iconBtnDelete : iconBtnUnlock}
                                  title={isActive ? 'Lock account' : 'Unlock account'}
                                  onClick={() => handleToggleStatus(customer)}
                                  disabled={isToggling}
                                  aria-busy={isToggling}
                                >
                                  {isToggling
                                    ? <span className="h-3.5 w-3.5 animate-spin-fast rounded-full border-2 border-current/30 border-t-current" />
                                    : isActive ? <Lock size={15} /> : <Unlock size={15} />
                                  }
                                </button>
                                <button type="button" className={iconBtnVehicle} title="Vehicle profile" onClick={() => setModal({ type: 'vehicle', customer })}>
                                  <Bike size={15} />
                                </button>
                                <button type="button" className={iconBtnMaintenance} title="Maintenance history" onClick={() => setModal({ type: 'maintenance', customer })}>
                                  <Wrench size={15} />
                                </button>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
                {/* Pagination Controls */}
                <div className="border-t border-edge p-4">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-ink-muted">
                      Showing {Math.min((currentPage - 1) * itemsPerPage + 1, filtered.length)} to {Math.min(currentPage * itemsPerPage, filtered.length)} of {filtered.length} entries
                    </span>
                    <div className="flex gap-2">
                      <button type="button" disabled={currentPage === 1} onClick={() => setCurrentPage(p => p - 1)} className="rounded-xl border border-edge bg-white px-3 py-1.5 text-sm font-semibold text-ink-muted hover:bg-primary-light hover:text-primary disabled:opacity-50">Prev</button>
                      <span className="flex items-center px-2 text-sm font-semibold text-ink-muted">Page {currentPage} of {totalPages}</span>
                      <button type="button" disabled={currentPage === totalPages} onClick={() => setCurrentPage(p => p + 1)} className="rounded-xl border border-edge bg-white px-3 py-1.5 text-sm font-semibold text-ink-muted hover:bg-primary-light hover:text-primary disabled:opacity-50">Next</button>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* ── Modals ─────────────────────────────────────────────────────────── */}
      {modal?.type === 'vehicle' && (
        <VehicleModal
          customerId={modal.customer.id}
          customerName={modal.customer.fullName || modal.customer.username}
          onClose={() => setModal(null)}
        />
      )}
      {modal?.type === 'maintenance' && (
        <MaintenanceModal
          customerId={modal.customer.id}
          customerName={modal.customer.fullName || modal.customer.username}
          onClose={() => setModal(null)}
        />
      )}
    </>
  );
};

export default CustomerManagement;
