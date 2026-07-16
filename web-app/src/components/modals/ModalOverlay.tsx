/**
 * ModalOverlay.tsx
 * ────────────────
 * Shared modal backdrop + container. Traps focus, closes on Escape key
 * and backdrop click.
 */
import React, { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';

interface ModalOverlayProps {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  isOpen?: boolean;
  icon?: React.ReactNode;
  /** Optional extra CSS class on the content panel (e.g., 'modal-content--wide') */
  contentClass?: string;
}

const ModalOverlay = ({ title, onClose, children, isOpen = true, icon, contentClass = '' }: ModalOverlayProps) => {
  const dialogRef = useRef<HTMLDivElement>(null);

  // Close on Escape key
  useEffect(() => {
    if (!isOpen) return;

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
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  // Close on backdrop click (not on content click)
  const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (dialogRef.current && !dialogRef.current.contains(e.target as Node)) {
      onClose();
    }
  };

  const modalContent = (
    <div
      className="fixed inset-0 z-[200] flex items-center justify-center p-4 backdrop-blur-[4px] animate-fade-in [background:rgba(15,23,42,0.55)]"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onClick={handleBackdropClick}
    >
      <div
        ref={dialogRef}
        className={`relative max-h-[90vh] w-full max-w-[500px] overflow-y-auto rounded-[18px] border border-edge bg-white shadow-float animate-scale-in ${contentClass}`}
      >
        {/* Top gradient accent */}
        <div className="absolute inset-x-0 top-0 z-[1] h-1 bg-gradient-to-r from-primary-bright via-primary to-primary-hover" />

        {/* Header */}
        <div className="flex items-center justify-between gap-4 border-b border-edge px-6 pb-4 pt-5">
          <div className="flex min-w-0 items-center gap-2">
            {icon && <span className="shrink-0 text-primary">{icon}</span>}
            <h2 className="m-0 text-[1.0625rem] font-bold tracking-tight text-ink">{title}</h2>
          </div>
          <button
            type="button"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[10px] border-none bg-transparent p-0 text-ink-muted transition-all duration-200 ease-spring hover:rotate-90 hover:bg-primary-light hover:text-primary"
            onClick={onClose}
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="px-6 py-5">{children}</div>
      </div>
    </div>
  );

  return createPortal(modalContent, document.body);
};

export default ModalOverlay;
