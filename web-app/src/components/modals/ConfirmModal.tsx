/**
 * ConfirmModal.tsx
 * ────────────────
 * Generic yes/no confirmation dialog.
 */
import { AlertTriangle } from 'lucide-react';
import ModalOverlay from './ModalOverlay';
import LoadingSpinner from '../ui/LoadingSpinner';

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
  confirmLabel = 'Xác nhận',
  cancelLabel = 'Hủy',
  isDestructive = false,
  isLoading = false,
  onConfirm,
  onClose,
}: ConfirmModalProps) => {
  return (
    <ModalOverlay title={title} onClose={onClose} contentClass="modal-content--sm">
      <div className="confirm-modal-body">
        <div className={`confirm-icon-wrap ${isDestructive ? 'confirm-icon-wrap--danger' : 'confirm-icon-wrap--warning'}`}>
          <AlertTriangle size={28} aria-hidden="true" />
        </div>
        <p className="confirm-message">{message}</p>
      </div>

      <div className="modal-footer">
        <button
          type="button"
          className="app-btn app-btn--outline"
          onClick={onClose}
          disabled={isLoading}
        >
          {cancelLabel}
        </button>
        <button
          type="button"
          className={`app-btn ${isDestructive ? 'app-btn--danger' : ''}`}
          onClick={onConfirm}
          disabled={isLoading}
          aria-busy={isLoading}
        >
          {isLoading ? (
            <>
              <LoadingSpinner size={15} color="#fff" />
              Đang xử lý...
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
