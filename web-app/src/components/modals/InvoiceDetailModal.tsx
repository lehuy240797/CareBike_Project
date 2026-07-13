import React, { Fragment } from 'react';
import ModalOverlay from './ModalOverlay';

export interface InvoiceItem {
  name?: string;
  quantity?: number;
  price?: number;
}

export interface InvoiceData {
  sourceType?: string;
  date?: string;
  customerName?: string;
  customerPhone?: string;
  vehicleName?: string;
  vehiclePlate?: string;
  staffCode?: string;
  staffName?: string;
  laborCost?: number;
  distanceKm?: number;
  transportFee?: number;
  totalAmount?: number;
  items?: InvoiceItem[];
}

interface InvoiceDetailModalProps {
  invoice: InvoiceData;
  onClose: () => void;
}

const asNumber = (value: unknown) =>
  typeof value === 'number'
    ? value
    : typeof value === 'string'
      ? Number(value) || 0
      : 0;

const formatCurrency = (amount = 0) =>
  `${Math.round(Number(amount || 0)).toLocaleString('vi-VN')} VNĐ`;

const CareBikeWordmark = () => (
  <div className="font-display text-3xl font-black italic leading-none tracking-tight">
    <span className="text-primary">CARE</span>
    <span className="text-ink">BIKE</span>
  </div>
);

const InvoiceSection = ({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) => (
  <div className="mb-4 rounded-2xl border border-edge p-4">
    <p className="mb-3 mt-0 text-xs font-black uppercase tracking-[2px] text-ink-muted">
      {title}
    </p>
    {children}
  </div>
);

const InvoiceGrid = ({ rows }: { rows: Array<[string, string | undefined]> }) => (
  <div className="grid grid-cols-[6rem_1fr] gap-x-4 gap-y-2 text-sm">
    {rows.map(([label, value]) => (
      <Fragment key={label}>
        <span className="text-ink-muted">{label}</span>
        <strong className="text-ink">{value || 'N/A'}</strong>
      </Fragment>
    ))}
  </div>
);

const InvoiceRow = ({ label, amount }: { label: string; amount: number }) => (
  <div className="mb-2 flex justify-between gap-5 text-sm text-ink">
    <span>{label}</span>
    <strong>{formatCurrency(amount)}</strong>
  </div>
);

const InvoiceDetailModal = ({ invoice, onClose }: InvoiceDetailModalProps) => {
  const serviceLabel = invoice.sourceType === 'RESCUE' ? 'Motorcycle Rescue Service' : 'Maintenance Service';

  return (
    <ModalOverlay
      title="Invoice Details"
      onClose={onClose}
      contentClass="max-w-[480px]"
    >
      <div className="rounded-3xl border border-edge bg-white p-5 shadow-card">
        <div className="mb-5 rounded-2xl bg-primary-light/60 px-4 py-5 text-center">
          <CareBikeWordmark />
          <p className="m-0 mt-1 text-xs font-semibold uppercase tracking-wide text-ink-muted">
            {serviceLabel}
          </p>
          <p className="m-0 mt-1 text-xs text-ink-muted">Date: {invoice.date}</p>
        </div>

        <InvoiceSection title="Customer Information">
          <InvoiceGrid rows={[
            ['Name', invoice.customerName],
            ['Phone', invoice.customerPhone],
            ['Vehicle', invoice.vehicleName],
            ['Plate', invoice.vehiclePlate],
          ]} />
        </InvoiceSection>

        <InvoiceSection title="Staff Information">
          <InvoiceGrid rows={[
            ['Staff Code', invoice.staffCode],
            ['Name', invoice.staffName],
          ]} />
        </InvoiceSection>

        <div className="rounded-2xl border border-edge p-4">
          <p className="mb-3 mt-0 text-xs font-black uppercase tracking-[2px] text-ink-muted">
            Services Used
          </p>
          {asNumber(invoice.laborCost) > 0 && (
            <InvoiceRow label="Rescue labor fee" amount={asNumber(invoice.laborCost)} />
          )}
          {invoice.items?.map((line, index) => (
            <InvoiceRow
              key={`${line.name}-${index}`}
              label={`${line.name || 'Service'} x${asNumber(line.quantity) || 1}`}
              amount={asNumber(line.price) * (asNumber(line.quantity) || 1)}
            />
          ))}
          {asNumber(invoice.transportFee) > 0 && (
            <InvoiceRow
              label={`Staff travel (${Number(invoice.distanceKm || 0).toFixed(1)}km - Round trip)`}
              amount={asNumber(invoice.transportFee)}
            />
          )}
        </div>

        <div className="mt-4 flex items-center justify-between rounded-2xl bg-ink px-4 py-3 text-white">
          <span className="font-display text-xl font-black text-white">TOTAL</span>
          <span className="font-display text-xl font-black text-primary-bright">
            {formatCurrency(invoice.totalAmount)}
          </span>
        </div>
      </div>
      <div className="mt-6 flex justify-end">
        <button type="button" className="rounded-xl border border-edge bg-white px-5 py-2.5 text-sm font-semibold text-ink transition hover:border-primary hover:text-primary" onClick={onClose}>
          Close
        </button>
      </div>
    </ModalOverlay>
  );
};

export default InvoiceDetailModal;
