import { useState, useEffect, useCallback } from 'react';
import { Building2, Plus, Pencil, Trash2 } from 'lucide-react';
import { getBranches, deleteBranch } from '../services/branchService';
import type { BranchRecord } from '../services/branchService';
import BranchModal from '../components/modals/BranchModal';
import ConfirmModal from '../components/modals/ConfirmModal';

// ─── Status badge config ──────────────────────────────────────────────────────

const STATUS_MAP: Record<string, { label: string; className: string }> = {
  ACTIVE: { label: 'Đang hoạt động', className: 'badge badge--success' },
  INACTIVE: { label: 'Tạm khóa', className: 'badge badge--danger' },
};

// ─── Component ────────────────────────────────────────────────────────────────

const BranchManagement = () => {
  const [branches, setBranches] = useState<BranchRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState('');

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
      setLoadError('Không thể tải dữ liệu chi nhánh. Vui lòng thử lại.');
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
      closeDeleteConfirm();
    } catch {
      /* keep modal open — user can retry */
    } finally {
      setIsDeleting(false);
    }
  };

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <>
      <div className="dashboard-inner">
        {/* Page header */}
        <div className="page-header" style={{ marginBottom: '1.75rem' }}>
          <Building2 size={28} className="page-header-icon" aria-hidden="true" />
          <div style={{ flex: 1 }}>
            <h1 className="dashboard-title" style={{ margin: 0 }}>Quản lý Chi nhánh</h1>
            <p className="page-subtitle">
              {!isLoading && !loadError ? `${branches.length} chi nhánh trong hệ thống` : 'Danh sách các chi nhánh'}
            </p>
          </div>
          <button type="button" className="app-btn" onClick={openCreate}>
            <Plus size={16} aria-hidden="true" />
            Thêm chi nhánh
          </button>
        </div>

        {/* Table card */}
        <div className="table-card">
          {isLoading ? (
            <div className="table-empty">
              <div className="table-spinner" aria-label="Đang tải..." />
              <p>Đang tải dữ liệu...</p>
            </div>
          ) : loadError ? (
            <div className="table-empty table-empty--error">
              <p>{loadError}</p>
              <button type="button" className="app-btn app-btn--outline" onClick={fetchBranches}>
                Thử lại
              </button>
            </div>
          ) : branches.length === 0 ? (
            <div className="table-empty">
              <Building2 size={40} aria-hidden="true" style={{ opacity: 0.3 }} />
              <p>Chưa có chi nhánh nào.</p>
              <button type="button" className="app-btn" onClick={openCreate}>
                <Plus size={15} />
                Tạo chi nhánh đầu tiên
              </button>
            </div>
          ) : (
            <div className="table-scroll">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Tên chi nhánh</th>
                    <th>Địa chỉ</th>
                    <th>Điện thoại</th>
                    <th>Quản lý</th>
                    <th>Trạng thái</th>
                    <th style={{ textAlign: 'right' }}>Thao tác</th>
                  </tr>
                </thead>
                <tbody>
                  {branches.map((branch) => {
                    const status = STATUS_MAP[branch.status?.toUpperCase()] ?? {
                      label: branch.status,
                      className: 'badge badge--neutral',
                    };
                    return (
                      <tr key={branch.id}>
                        <td className="td-muted">{branch.id}</td>
                        <td className="td-primary">{branch.name}</td>
                        <td>{branch.address ?? '—'}</td>
                        <td>{branch.phone ?? '—'}</td>
                        <td>
                          {branch.manager ? (
                            <span className="font-medium">
                              {branch.manager.fullName || branch.manager.email || `ID: ${branch.manager.id}`}
                            </span>
                          ) : (
                            <span className="td-muted">Chưa có</span>
                          )}
                        </td>
                        <td><span className={status.className}>{status.label}</span></td>
                        <td>
                          <div className="table-actions">
                            <button
                              type="button"
                              className="icon-btn icon-btn--edit"
                              title="Chỉnh sửa"
                              onClick={() => openEdit(branch)}
                            >
                              <Pencil size={15} />
                            </button>
                            <button
                              type="button"
                              className="icon-btn icon-btn--delete"
                              title="Xóa chi nhánh"
                              onClick={() => openDeleteConfirm(branch)}
                            >
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
          )}
        </div>
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
          title="Xóa chi nhánh"
          message={`Bạn có chắc muốn xóa chi nhánh "${confirmModal.branch.name}"? Hành động này không thể hoàn tác.`}
          confirmLabel="Xóa"
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