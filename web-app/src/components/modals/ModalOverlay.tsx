/**
 * ModalOverlay.tsx
 * ────────────────
 * Shared modal backdrop + container. Traps focus, closes on Escape key
 * and backdrop click.
 */
import React, { useEffect, useRef } from 'react';
import { X } from 'lucide-react';

interface ModalOverlayProps {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  /** Optional extra CSS class on the content panel (e.g., 'modal-content--wide') */
  contentClass?: string;
}

const ModalOverlay = ({ title, onClose, children, contentClass = '' }: ModalOverlayProps) => {
  const dialogRef = useRef<HTMLDivElement>(null);

  // Close on Escape key
  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKey);
    // Prevent body scroll while modal is open
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', handleKey);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  // Close on backdrop click (not on content click)
  const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (dialogRef.current && !dialogRef.current.contains(e.target as Node)) {
      onClose();
    }
  };

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onClick={handleBackdropClick}
    >
      <div
        ref={dialogRef}
        className={`modal-content ${contentClass}`}
      >
        {/* Header */}
        <div className="modal-header">
          <h2 className="modal-title">{title}</h2>
          <button
            type="button"
            className="modal-close-btn"
            onClick={onClose}
            aria-label="Đóng"
          >
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="modal-body">
          {children}
        </div>
      </div>
    </div>
  );
};

export default ModalOverlay;
