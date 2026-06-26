/**
 * LoadingSpinner.tsx
 * ──────────────────
 * Reusable inline spinner. Used on submit buttons and loading states.
 */

interface LoadingSpinnerProps {
  size?: number;
  color?: string;
  className?: string;
}

const LoadingSpinner = ({
  size = 18,
  color = 'currentColor',
  className = '',
}: LoadingSpinnerProps) => (
  <svg
    className={`animate-spin-fast ${className}`}
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
  >
    <circle
      cx="12"
      cy="12"
      r="10"
      stroke={color}
      strokeWidth="3"
      strokeOpacity="0.25"
    />
    <path
      d="M12 2a10 10 0 0 1 10 10"
      stroke={color}
      strokeWidth="3"
      strokeLinecap="round"
    />
  </svg>
);

export default LoadingSpinner;
