import { useState, useEffect, useCallback } from 'react';
import { Users, Lock, Unlock, Bike, Wrench, Star } from 'lucide-react';
import { getCustomers } from '../services/customerService';
import { apiToggleUserStatus } from '../services/userService';
import { getAllProfiles } from '../services/customerProfileService';
import type { UserRecord } from '../services/userService';
import type { CustomerProfile, MemberTier } from '../types/api';
import VehicleModal from '../components/modals/VehicleModal';
import MaintenanceModal from '../components/modals/MaintenanceModal';

// ─── Tier badge config ────────────────────────────────────────────────────────

const TIER_CONFIG: Record<MemberTier, { label: string; className: string }> = {
  STANDARD: { label: 'Tiêu chuẩn', className: 'badge badge--neutral'   },
  SILVER:   { label: 'Bạc',        className: 'badge badge--silver'     },
  GOLD:     { label: 'Vàng',       className: 'badge badge--gold'       },
  PLATINUM: { label: 'Bạch kim',   className: 'badge badge--platinum'   },
};

// ─── Sub-types ────────────────────────────────────────────────────────────────

type ModalState =
  | { type: 'vehicle';     customer: UserRecord }
  | { type: 'maintenance'; customer: UserRecord }
  | null;

// ─── Helpers ──────────────────────────────────────────────────────────────────

const formatDate = (dateStr: string) => {
  try {
    return new Date(dateStr).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' });
  } catch { return '—'; }
};

const formatPoints = (pts: number) =>
  new Intl.NumberFormat('vi-VN').format(pts) + ' điểm';

// ─── Component ────────────────────────────────────────────────────────────────

const CustomerManagement = () => {
  const [customers, setCustomers]           = useState<UserRecord[]>([]);
  const [profiles, setProfiles]             = useState<Map<number, CustomerProfile>>(new Map());
  const [isLoading, setIsLoading]           = useState(true);
  const [loadError, setLoadError]           = useState('');
  const [modal, setModal]                   = useState<ModalState>(null);
  const [togglingId, setTogglingId]         = useState<number | null>(null);

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
      setLoadError('Không thể tải danh sách khách hàng. Vui lòng thử lại.');
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

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <>
      <div className="dashboard-inner">
        {/* Page header */}
        <div className="page-header" style={{ marginBottom: '1.75rem' }}>
          <Users size={28} className="page-header-icon" aria-hidden="true" />
          <div>
            <h1 className="dashboard-title" style={{ margin: 0 }}>Quản lý Khách hàng</h1>
            <p className="page-subtitle">
              {!isLoading && !loadError
                ? `${customers.length} tài khoản khách hàng`
                : 'Danh sách tài khoản khách hàng'}
            </p>
          </div>
        </div>

        {/* Table card */}
        <div className="table-card">
          {isLoading ? (
            <div className="table-empty">
              <div className="table-spinner" aria-label="Đang tải..." />
              <p>Đang tải danh sách khách hàng...</p>
            </div>
          ) : loadError ? (
            <div className="table-empty table-empty--error">
              <p>{loadError}</p>
              <button type="button" className="app-btn app-btn--outline" onClick={fetchAll}>Thử lại</button>
            </div>
          ) : customers.length === 0 ? (
            <div className="table-empty">
              <Users size={40} aria-hidden="true" style={{ opacity: 0.3 }} />
              <p>Chưa có khách hàng nào.</p>
            </div>
          ) : (
            <div className="table-scroll">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Họ và tên</th>
                    <th>Tài khoản / Email</th>
                    <th>Ngày đăng ký</th>
                    <th>Hạng thành viên</th>
                    <th>Điểm tích lũy</th>
                    <th>Trạng thái</th>
                    <th style={{ textAlign: 'right' }}>Thao tác</th>
                  </tr>
                </thead>
                <tbody>
                  {customers.map((customer) => {
                    const isActive = customer.isActive !== false;
                    const isToggling = togglingId === customer.id;
                    const profile = profiles.get(customer.id);
                    const tier = (profile?.memberTier as MemberTier) ?? 'STANDARD';
                    const tierCfg = TIER_CONFIG[tier];

                    return (
                      <tr key={customer.id}>
                        {/* ID */}
                        <td className="td-muted">#{customer.id}</td>

                        {/* Name + phone */}
                        <td>
                          <div className="td-primary">{customer.fullName || '—'}</div>
                          <div className="td-sub">{customer.phone || '—'}</div>
                        </td>

                        {/* Username + email */}
                        <td>
                          <div>{customer.username}</div>
                          <div className="td-sub">{customer.email}</div>
                        </td>

                        {/* Joined date */}
                        <td>{formatDate(customer.createdAt)}</td>

                        {/* Loyalty tier */}
                        <td>
                          <span className={tierCfg.className}>
                            {tier !== 'STANDARD' && <Star size={10} style={{ marginRight: '0.25rem', verticalAlign: 'middle' }} />}
                            {tierCfg.label}
                          </span>
                        </td>

                        {/* Points */}
                        <td>
                          {profile
                            ? <span className="loyalty-points">{formatPoints(profile.accumulatedPoints)}</span>
                            : <span className="td-muted">—</span>
                          }
                        </td>

                        {/* Account status */}
                        <td>
                          <span className={`badge ${isActive ? 'badge--success' : 'badge--danger'}`}>
                            {isActive ? 'Hoạt động' : 'Đã khóa'}
                          </span>
                        </td>

                        {/* Actions */}
                        <td>
                          <div className="table-actions">
                            {/* A: Lock / Unlock */}
                            <button
                              type="button"
                              className={`icon-btn ${isActive ? 'icon-btn--delete' : 'icon-btn--unlock'}`}
                              title={isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản'}
                              onClick={() => handleToggleStatus(customer)}
                              disabled={isToggling}
                              aria-busy={isToggling}
                            >
                              {isToggling
                                ? <span className="table-spinner" style={{ width: '14px', height: '14px', borderWidth: '2px' }} />
                                : isActive ? <Lock size={15} /> : <Unlock size={15} />
                              }
                            </button>

                            {/* B: Vehicle profile (read-only) */}
                            <button
                              type="button"
                              className="icon-btn icon-btn--vehicle"
                              title="Hồ sơ xe máy"
                              onClick={() => setModal({ type: 'vehicle', customer })}
                            >
                              <Bike size={15} />
                            </button>

                            {/* C: Maintenance history */}
                            <button
                              type="button"
                              className="icon-btn icon-btn--maintenance"
                              title="Lịch sử bảo dưỡng"
                              onClick={() => setModal({ type: 'maintenance', customer })}
                            >
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
          )}
        </div>
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