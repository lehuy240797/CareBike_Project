/**
 * VehicleModal.tsx  (READ-ONLY)
 * ─────────────────────────────
 * Admin view of a customer's motorbike profile — no editing.
 * Customers manage their vehicle via the Mobile App (Flutter).
 *
 * GET /api/vehicles/owner/{userId}
 *   200 → display profile details
 *   404 → show "not updated via mobile app" message
 */
import { useState, useEffect } from 'react';
import { Bike, AlertCircle, Smartphone } from 'lucide-react';
import ModalOverlay from './ModalOverlay';
import LoadingSpinner from '../ui/LoadingSpinner';
import { getVehicleByOwner } from '../../services/vehicleService';
import type { VehicleRecord } from '../../types/api';

interface VehicleModalProps {
  customerId: number;
  customerName: string;
  onClose: () => void;
}

const VEHICLE_TYPES: Record<string, string> = {
  XE_SO: 'Xe số',
  XE_TAY_GA: 'Xe tay ga',
};

const VehicleModal = ({ customerId, customerName, onClose }: VehicleModalProps) => {
  const [vehicle, setVehicle] = useState<VehicleRecord | null>(null);
  const [notFound, setNotFound] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const load = async () => {
      setIsLoading(true);
      setError('');
      setNotFound(false);
      try {
        const data = await getVehicleByOwner(customerId);
        setVehicle(data);
      } catch (err: unknown) {
        const status = (err as { response?: { status?: number } })?.response?.status;
        if (status === 404) {
          setNotFound(true);
        } else {
          setError('Không thể tải hồ sơ xe. Vui lòng thử lại.');
        }
      } finally {
        setIsLoading(false);
      }
    };
    load();
  }, [customerId]);

  const typeLabel = (type: string) => VEHICLE_TYPES[type] ?? type;

  return (
    <ModalOverlay
      title={`Hồ sơ xe máy — ${customerName}`}
      onClose={onClose}
      contentClass="modal-content--md"
    >
      {/* ── Loading ──────────────────────────────────────────────────── */}
      {isLoading && (
        <div className="modal-loading">
          <LoadingSpinner size={32} color="var(--color-primary)" />
          <p>Đang tải hồ sơ xe...</p>
        </div>
      )}

      {/* ── Network error ─────────────────────────────────────────────── */}
      {!isLoading && error && (
        <div className="modal-error-state">
          <AlertCircle size={40} aria-hidden="true" />
          <p>{error}</p>
        </div>
      )}

      {/* ── Not found: customer hasn't updated via mobile ──────────────── */}
      {!isLoading && notFound && (
        <div className="modal-empty-state">
          <Smartphone size={52} strokeWidth={1.2} aria-hidden="true" style={{ color: 'var(--color-primary)', opacity: 0.6 }} />
          <p style={{ fontWeight: 600 }}>Chưa có hồ sơ xe</p>
          <p style={{ fontSize: '0.875rem', maxWidth: '28ch', textAlign: 'center' }}>
            Khách hàng này chưa cập nhật hồ sơ xe máy trên ứng dụng di động.
          </p>
        </div>
      )}

      {/* ── Vehicle profile (read-only) ────────────────────────────────── */}
      {!isLoading && vehicle && (
        <>
          {/* Hero row */}
          <div className="vehicle-profile-grid">
            <div className="vehicle-icon-col" aria-hidden="true">
              <Bike size={64} strokeWidth={1} className="vehicle-big-icon" />
            </div>
            <div className="vehicle-info-col">
              <div className="vehicle-model-name">{vehicle.vehicleName}</div>
              <div className="vehicle-brand-row">
                <span className="badge badge--neutral">{vehicle.brand}</span>
                <span className="badge badge--neutral">{typeLabel(vehicle.vehicleType)}</span>
              </div>
            </div>
          </div>

          {/* Detail table */}
          <div className="detail-list">
            {[
              { label: 'Hãng xe',   value: vehicle.brand },
              { label: 'Dòng xe',   value: typeLabel(vehicle.vehicleType) },
              { label: 'Tên xe',    value: vehicle.vehicleName },
              { label: 'Số khung',  value: vehicle.chassisNumber || '—', mono: true },
              { label: 'Số máy',    value: vehicle.engineNumber  || '—', mono: true },
            ].map(({ label, value, mono }) => (
              <div key={label} className="detail-row">
                <span className="detail-label">{label}</span>
                <span className={`detail-value${mono ? ' detail-value--mono' : ''}`}>{value}</span>
              </div>
            ))}
          </div>

          <p className="form-hint" style={{ marginTop: '0.75rem' }}>
            🔒 Hồ sơ xe chỉ có thể được cập nhật bởi khách hàng qua ứng dụng di động.
          </p>
        </>
      )}

      {/* Footer */}
      {!isLoading && (
        <div className="modal-footer" style={{ marginTop: '1rem' }}>
          <button type="button" className="app-btn app-btn--outline" onClick={onClose}>
            Đóng
          </button>
        </div>
      )}
    </ModalOverlay>
  );
};

export default VehicleModal;
