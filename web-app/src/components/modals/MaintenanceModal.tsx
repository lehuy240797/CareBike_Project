/**
 * MaintenanceModal.tsx
 * ────────────────────
 * Displays maintenance history timeline for a specific customer.
 * Fetches GET /api/maintenance/customer/{userId} on open.
 */
import { useState, useEffect } from 'react';
import { Wrench, AlertCircle, CalendarDays, Gauge, DollarSign, MapPin, ClipboardList } from 'lucide-react';
import ModalOverlay from './ModalOverlay';
import LoadingSpinner from '../ui/LoadingSpinner';
import { getMaintenanceByCustomer } from '../../services/maintenanceService';
import type { MaintenanceRecord } from '../../types/api';
import { btnOutline, modalFooter } from '../../ui/styles';

interface MaintenanceModalProps {
  customerId: number;
  customerName: string;
  onClose: () => void;
}

const formatDate = (dateStr: string): string => {
  try {
    const [year, month, day] = dateStr.split('-');
    return `${day}/${month}/${year}`;
  } catch {
    return dateStr;
  }
};

const formatCurrency = (amount: number | null): string => {
  if (amount === null || amount === undefined) return '—';
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
  }).format(amount);
};

const formatKm = (km: number | null): string => {
  if (km === null || km === undefined) return '—';
  return `${new Intl.NumberFormat('vi-VN').format(km)} km`;
};

const MaintenanceModal = ({ customerId, customerName, onClose }: MaintenanceModalProps) => {
  const [records, setRecords] = useState<MaintenanceRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const load = async () => {
      setIsLoading(true);
      setError('');
      try {
        const data = await getMaintenanceByCustomer(customerId);
        setRecords(data);
      } catch {
        setError('Could not load maintenance history. Please try again.');
      } finally {
        setIsLoading(false);
      }
    };
    load();
  }, [customerId]);

  return (
    <ModalOverlay
      title={`Maintenance history — ${customerName}`}
      onClose={onClose}
      contentClass="max-w-[680px]"
    >
      {isLoading ? (
        <div className="flex flex-col items-center justify-center gap-4 px-4 py-10 text-[0.9375rem] text-ink-muted">
          <LoadingSpinner size={32} color="var(--color-primary)" />
          <p className="m-0">Loading maintenance history...</p>
        </div>
      ) : error ? (
        <div className="flex flex-col items-center gap-3.5 px-4 py-10 text-center text-red-600">
          <AlertCircle size={40} aria-hidden="true" />
          <p className="m-0 text-[0.9375rem]">{error}</p>
        </div>
      ) : records.length === 0 ? (
        <div className="flex flex-col items-center gap-3.5 px-4 py-10 text-center text-ink-muted">
          <Wrench size={48} strokeWidth={1.2} aria-hidden="true" />
          <p className="m-0 text-[0.9375rem]">This customer has no maintenance history yet.</p>
        </div>
      ) : (
        <>
          <div className="mb-5 inline-flex items-center gap-1.5 rounded-full bg-gradient-to-br from-primary-bright via-primary to-primary-hover px-3 py-1 text-[0.8125rem] font-semibold text-white">
            <ClipboardList size={14} aria-hidden="true" />
            <span>{records.length} service record(s)</span>
          </div>

          {/* Timeline */}
          <div className="flex flex-col">
            {records.map((record, index) => (
              <div key={record.id} className="flex items-start gap-3.5">
                {/* Timeline line + dot */}
                <div className="flex w-5 shrink-0 flex-col items-center pt-[0.3rem]">
                  <div className="h-3 w-3 shrink-0 rounded-full bg-primary shadow-[0_0_0_3px_var(--color-primary-muted)]" />
                  {index < records.length - 1 && <div className="my-1.5 min-h-5 w-0.5 flex-1 bg-edge" />}
                </div>

                {/* Content */}
                <div className="mb-3.5 min-w-0 flex-1 rounded-[14px] border border-edge bg-white px-4 py-3.5 transition-shadow duration-150 hover:shadow-soft">
                  {/* Card header */}
                  <div className="mb-2.5 flex flex-wrap items-start justify-between gap-2">
                    <div className="flex flex-wrap items-center gap-2.5">
                      <span className="inline-flex items-center gap-1.5 text-[0.8125rem] font-medium text-ink-muted">
                        <CalendarDays size={13} aria-hidden="true" />
                        {formatDate(record.serviceDate)}
                      </span>
                      {record.currentKm !== null && (
                        <span className="inline-flex items-center gap-1.5 text-[0.8125rem] font-medium text-ink-muted">
                          <Gauge size={13} aria-hidden="true" />
                          {formatKm(record.currentKm)}
                        </span>
                      )}
                      {record.branch && (
                        <span className="inline-flex items-center gap-1.5 text-[0.8125rem] font-medium text-ink-muted">
                          <MapPin size={13} aria-hidden="true" />
                          {record.branch.name}
                        </span>
                      )}
                    </div>
                    <div className="inline-flex shrink-0 items-center gap-1 text-[0.9375rem] font-bold text-primary-deep">
                      <DollarSign size={14} aria-hidden="true" />
                      {formatCurrency(record.totalCost)}
                    </div>
                  </div>

                  {/* Service details */}
                  {record.serviceDetails && (
                    <div className="flex flex-wrap gap-1.5">
                      {record.serviceDetails.split(',').map((detail, i) => (
                        <span
                          key={i}
                          className="inline-block rounded-full border border-primary-muted bg-primary-light px-2.5 py-0.5 text-[0.8125rem] font-medium text-primary transition-all duration-150 ease-spring hover:-translate-y-px hover:bg-primary-muted"
                        >
                          {detail.trim()}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      <div className={modalFooter}>
        <button type="button" className={btnOutline} onClick={onClose}>
          Close
        </button>
      </div>
    </ModalOverlay>
  );
};

export default MaintenanceModal;
