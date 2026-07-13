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
import { badgeBase, btnOutline, formHint, modalFooter } from '../../ui/styles';

interface VehicleModalProps {
  customerId: number;
  customerName: string;
  onClose: () => void;
}

const VEHICLE_TYPES: Record<string, string> = {
  XE_SO: 'Manual',
  XE_TAY_GA: 'Scooter',
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
        if (Array.isArray(data) && data.length > 0) {
          setVehicle(data[0]);
        } else {
          setNotFound(true);
        }
      } catch (err: unknown) {
        const status = (err as { response?: { status?: number } })?.response?.status;
        if (status === 404) {
          setNotFound(true);
        } else {
          setError('Could not load the vehicle profile. Please try again.');
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
      title={`Vehicle profile — ${customerName}`}
      onClose={onClose}
      contentClass="max-w-[560px]"
    >
      {/* ── Loading ──────────────────────────────────────────────────── */}
      {isLoading && (
        <div className="flex flex-col items-center justify-center gap-4 px-4 py-10 text-[0.9375rem] text-ink-muted">
          <LoadingSpinner size={32} color="var(--color-primary)" />
          <p className="m-0">Loading vehicle profile...</p>
        </div>
      )}

      {/* ── Network error ─────────────────────────────────────────────── */}
      {!isLoading && error && (
        <div className="flex flex-col items-center gap-3.5 px-4 py-10 text-center text-red-600">
          <AlertCircle size={40} aria-hidden="true" />
          <p className="m-0 text-[0.9375rem]">{error}</p>
        </div>
      )}

      {/* ── Not found: customer hasn't updated via mobile ──────────────── */}
      {!isLoading && notFound && (
        <div className="flex flex-col items-center gap-3.5 px-4 py-10 text-center text-ink-muted">
          <Smartphone size={52} strokeWidth={1.2} aria-hidden="true" className="text-primary opacity-60" />
          <p className="m-0 font-semibold">No vehicle profile</p>
          <p className="m-0 max-w-[28ch] text-center text-sm">
            This customer has not added a vehicle profile in the mobile app yet.
          </p>
        </div>
      )}

      {/* ── Vehicle profile (read-only) ────────────────────────────────── */}
      {!isLoading && vehicle && (
        <>
          {/* Hero row */}
          <div className="mb-4 flex items-center gap-6 border-b border-edge pb-5 pt-4">
            <div className="shrink-0 text-primary opacity-65" aria-hidden="true">
              <Bike size={64} strokeWidth={1} className="block" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="mb-2 break-words text-[1.375rem] font-bold tracking-tight text-ink">{vehicle.vehicleName}</div>
              <div className="flex flex-wrap gap-2">
                <span className={`${badgeBase} bg-stone-100 text-ink-muted`}>{vehicle.brand}</span>
                <span className={`${badgeBase} bg-stone-100 text-ink-muted`}>{typeLabel(vehicle.vehicleType)}</span>
              </div>
            </div>
          </div>

          {/* Detail table */}
          <div className="flex flex-col overflow-hidden rounded-[14px] border border-edge">
            {[
              { label: 'Brand',          value: vehicle.brand },
              { label: 'Type',           value: typeLabel(vehicle.vehicleType) },
              { label: 'Model name',     value: vehicle.vehicleName },
              { label: 'License plate',  value: vehicle.licensePlate  || '—', mono: true },
              { label: 'Engine capacity',value: vehicle.engineCapacity ? `${vehicle.engineCapacity} cc` : '—' },
              { label: 'Current mileage',value: vehicle.currentKm ? `${vehicle.currentKm.toLocaleString()} km` : '—' },
            ].map(({ label, value, mono }) => (
              <div key={label} className="flex items-center gap-4 border-b border-edge px-4 py-3 last:border-b-0 even:bg-stone-50">
                <span className="min-w-[9rem] shrink-0 text-sm font-semibold text-ink-muted">{label}</span>
                <span className={`break-all text-[0.9375rem] text-ink${mono ? ' font-mono text-sm tracking-wide text-stone-700' : ''}`}>{value}</span>
              </div>
            ))}
          </div>

          <p className={`${formHint} mt-3`}>
            🔒 The vehicle profile can only be updated by the customer via the mobile app.
          </p>
        </>
      )}

      {/* Footer */}
      {!isLoading && (
        <div className={modalFooter}>
          <button type="button" className={btnOutline} onClick={onClose}>
            Close
          </button>
        </div>
      )}
    </ModalOverlay>
  );
};

export default VehicleModal;
