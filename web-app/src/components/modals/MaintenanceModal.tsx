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
        setError('Không thể tải lịch sử bảo dưỡng. Vui lòng thử lại.');
      } finally {
        setIsLoading(false);
      }
    };
    load();
  }, [customerId]);

  return (
    <ModalOverlay
      title={`Lịch sử bảo dưỡng — ${customerName}`}
      onClose={onClose}
      contentClass="modal-content--lg"
    >
      {isLoading ? (
        <div className="modal-loading">
          <LoadingSpinner size={32} color="var(--color-primary)" />
          <p>Đang tải lịch sử bảo dưỡng...</p>
        </div>
      ) : error ? (
        <div className="modal-error-state">
          <AlertCircle size={40} aria-hidden="true" />
          <p>{error}</p>
        </div>
      ) : records.length === 0 ? (
        <div className="modal-empty-state">
          <Wrench size={48} strokeWidth={1.2} aria-hidden="true" />
          <p>Khách hàng này chưa có lịch sử bảo dưỡng nào.</p>
        </div>
      ) : (
        <>
          <div className="maintenance-count-badge">
            <ClipboardList size={14} aria-hidden="true" />
            <span>{records.length} lần bảo dưỡng</span>
          </div>

          {/* Timeline */}
          <div className="timeline">
            {records.map((record, index) => (
              <div key={record.id} className="timeline-item">
                {/* Timeline line + dot */}
                <div className="timeline-left">
                  <div className="timeline-dot" />
                  {index < records.length - 1 && <div className="timeline-line" />}
                </div>

                {/* Content */}
                <div className="timeline-card">
                  {/* Card header */}
                  <div className="timeline-card-header">
                    <div className="timeline-meta">
                      <span className="timeline-meta-item">
                        <CalendarDays size={13} aria-hidden="true" />
                        {formatDate(record.serviceDate)}
                      </span>
                      {record.currentKm !== null && (
                        <span className="timeline-meta-item">
                          <Gauge size={13} aria-hidden="true" />
                          {formatKm(record.currentKm)}
                        </span>
                      )}
                      {record.branch && (
                        <span className="timeline-meta-item">
                          <MapPin size={13} aria-hidden="true" />
                          {record.branch.name}
                        </span>
                      )}
                    </div>
                    <div className="timeline-cost">
                      <DollarSign size={14} aria-hidden="true" />
                      {formatCurrency(record.totalCost)}
                    </div>
                  </div>

                  {/* Service details */}
                  {record.serviceDetails && (
                    <div className="timeline-details">
                      {record.serviceDetails.split(',').map((detail, i) => (
                        <span key={i} className="service-tag">{detail.trim()}</span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      <div className="modal-footer" style={{ marginTop: '1rem' }}>
        <button type="button" className="app-btn app-btn--outline" onClick={onClose}>
          Đóng
        </button>
      </div>
    </ModalOverlay>
  );
};

export default MaintenanceModal;
