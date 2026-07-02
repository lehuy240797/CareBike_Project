/**
 * ConfirmModal.tsx
 * ────────────────
 * Generic yes/no confirmation dialog.
 */
import { AlertTriangle } from 'lucide-react';
import ModalOverlay from './ModalOverlay';
import LoadingSpinner from '../ui/LoadingSpinner';
import { btnOutline, btnPrimary, btnDanger } from '../../ui/styles';

interface ConfirmModalProps {
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  isDestructive?: boolean;
  isLoading?: boolean;
  onConfirm: () => void;
  onClose: () => void;
}

const ConfirmModal = ({
  title,
  message,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  isDestructive = false,
  isLoading = false,
  onConfirm,
  onClose,
}: ConfirmModalProps) => {
  return (
    <ModalOverlay title={title} onClose={onClose} contentClass="max-w-[400px]">
      <div className="flex flex-col items-center gap-4 px-0 pb-4 pt-2 text-center">
        <div
          className={`flex h-16 w-16 items-center justify-center rounded-full ${
            isDestructive ? 'bg-red-50 text-red-600' : 'bg-amber-50 text-amber-700'
          }`}
        >
          <AlertTriangle size={28} aria-hidden="true" />
        </div>
        <p className="m-0 max-w-[30ch] text-[0.9375rem] leading-relaxed text-ink">{message}</p>
      </div>

      <div className="mt-2 flex items-center justify-end gap-2.5 border-t border-edge pt-5">
        <button type="button" className={btnOutline} onClick={onClose} disabled={isLoading}>
          {cancelLabel}
        </button>
        <button
          type="button"
          className={isDestructive ? btnDanger : btnPrimary}
          onClick={onConfirm}
          disabled={isLoading}
          aria-busy={isLoading}
        >
          {isLoading ? (
            <>
              <LoadingSpinner size={15} color="#fff" />
              Processing...
            </>
          ) : (
            confirmLabel
          )}
        </button>
      </div>
    </ModalOverlay>
  );
};

export default ConfirmModal;
