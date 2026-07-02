/**
 * styles.ts — shared Tailwind class strings for repeated primitives.
 * These are plain utility strings (scanned by Tailwind), composed in JSX.
 */

/* Buttons — my-app style: solid orange, rounded-xl, hover lift + glow */
export const btnPrimary =
  'inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-white whitespace-nowrap select-none no-underline shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:bg-primary-hover hover:no-underline hover:shadow-[0_0_22px_rgba(249,115,22,0.40)] active:translate-y-0 disabled:cursor-not-allowed disabled:opacity-65 disabled:hover:translate-y-0';

export const btnOutline =
  'inline-flex items-center justify-center gap-2 rounded-xl border border-edge bg-white px-5 py-2.5 text-sm font-semibold text-primary whitespace-nowrap select-none no-underline transition-all duration-200 hover:-translate-y-0.5 hover:border-primary hover:bg-primary hover:text-white hover:no-underline active:translate-y-0 disabled:cursor-not-allowed disabled:opacity-65';

export const btnDanger =
  'inline-flex items-center justify-center gap-2 rounded-xl bg-red-600 px-5 py-2.5 text-sm font-semibold text-white whitespace-nowrap select-none shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:bg-red-700 hover:shadow-[0_0_22px_rgba(239,68,68,0.40)] active:translate-y-0 disabled:cursor-not-allowed disabled:opacity-65';

/* Surfaces — my-app rounded-3xl card with warm orange glow on hover */
export const card =
  'rounded-3xl border border-edge bg-white p-6 transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_0_25px_rgba(249,115,22,0.35)]';

/* Eyebrow — small uppercase Orbitron label above headings */
export const eyebrow = 'font-orb text-xs font-semibold uppercase tracking-[3px] text-primary';

/* Forms */
export const inputBase =
  'w-full rounded-xl border-[1.5px] border-edge bg-white px-3.5 py-2.5 text-[0.9375rem] text-ink transition-[border-color,box-shadow,transform] duration-150 placeholder:text-sm placeholder:text-stone-400 hover:border-stone-300 focus:border-primary focus:outline-none focus:shadow-[0_0_0_3px_rgba(249,115,22,0.28)] disabled:cursor-not-allowed disabled:bg-stone-50 disabled:opacity-60';

export const label = 'text-sm font-semibold text-ink';
export const fieldError = 'text-[0.8125rem] leading-snug text-red-600';
export const formGroup = 'flex flex-col gap-1.5';
export const formHint = 'mt-0.5 text-[0.8125rem] leading-snug text-ink-muted';
export const required = 'ml-0.5 text-red-600';
export const modalForm = 'flex flex-col gap-4';
export const modalFooter =
  'mt-2 flex items-center justify-end gap-2.5 border-t border-edge pt-5';

/* Native select styled like the inputs (with chevron) */
export const selectBase =
  "w-full cursor-pointer appearance-none rounded-xl border-[1.5px] border-edge bg-white px-3.5 py-2.5 pr-9 text-[0.9375rem] text-ink transition-[border-color,box-shadow] duration-150 bg-[length:14px] bg-[position:right_0.75rem_center] bg-no-repeat [background-image:url(\"data:image/svg+xml,%3Csvg_xmlns='http://www.w3.org/2000/svg'_width='14'_height='14'_viewBox='0_0_24_24'_fill='none'_stroke='%2378716c'_stroke-width='2.5'_stroke-linecap='round'_stroke-linejoin='round'%3E%3Cpolyline_points='6_9_12_15_18_9'/%3E%3C/svg%3E\")] focus:border-primary focus:outline-none focus:shadow-[0_0_0_3px_rgba(249,115,22,0.28)] disabled:cursor-not-allowed disabled:opacity-60";

/* Badges */
export const badgeBase =
  'inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-[0.8125rem] font-semibold transition-transform duration-150 ease-spring hover:-translate-y-px';
export const badgeSuccess = `${badgeBase} bg-green-50 text-green-700`;
export const badgeDanger = `${badgeBase} bg-red-50 text-red-600`;
export const badgeNeutral = `${badgeBase} bg-stone-100 text-ink-muted`;

/* Loyalty tier badges */
export const badgeSilver = `${badgeBase} border border-slate-400 bg-gradient-to-br from-slate-200 to-slate-300 font-bold text-slate-600`;
export const badgeGold = `${badgeBase} border border-amber-400 bg-gradient-to-br from-yellow-100 to-amber-200 font-bold text-amber-800`;
export const badgePlatinum = `${badgeBase} border border-sky-400 bg-gradient-to-br from-sky-100 to-sky-200 font-bold text-sky-900 shadow-[0_0_6px_rgba(56,189,248,0.3)]`;
export const loyaltyPoints = 'tabular-nums text-sm font-semibold text-primary-deep';

/* Tables */
export const tableCard = 'overflow-hidden rounded-3xl border border-edge bg-white shadow-sm';
export const tableScroll = 'overflow-x-auto';
export const dataTable = 'w-full border-collapse text-[0.9375rem]';
export const thCell =
  'whitespace-nowrap border-b border-edge bg-primary-light/60 px-4 py-3.5 text-left font-orb text-[0.6875rem] font-semibold uppercase tracking-[2px] text-ink-muted';
export const tdCell = 'border-b border-edge px-4 py-3.5 align-middle text-ink';
export const tableRow = 'transition-colors duration-150 hover:bg-primary-light';
export const tableEmpty =
  'flex flex-col items-center justify-center gap-3 px-6 py-12 text-center text-[0.9375rem] text-ink-muted';

/* Icon action buttons */
const iconBtnBase =
  'inline-flex h-8 w-8 items-center justify-center rounded-[10px] border-none transition-all duration-150 ease-spring hover:-translate-y-0.5 active:scale-95 disabled:cursor-not-allowed disabled:opacity-55 disabled:hover:translate-y-0';
export const iconBtnEdit = `${iconBtnBase} bg-blue-50 text-blue-500 hover:bg-blue-100`;
export const iconBtnDelete = `${iconBtnBase} bg-red-50 text-red-600 hover:bg-red-200`;
export const iconBtnUnlock = `${iconBtnBase} bg-green-50 text-green-700 hover:bg-green-200`;
export const iconBtnVehicle = `${iconBtnBase} bg-blue-50 text-blue-500 hover:bg-blue-100`;
export const iconBtnMaintenance = `${iconBtnBase} bg-amber-50 text-amber-600 hover:bg-amber-200`;

/* Loading spinner border (table states) */
export const tableSpinner =
  'h-8 w-8 animate-spin-fast rounded-full border-[3px] border-edge border-t-primary';

/* Page header heading — my-app big black heading */
export const dashTitle =
  'm-0 font-display text-3xl md:text-4xl font-black tracking-tight text-ink';

export const pageSubtitle = 'mt-1 mb-0 font-pop text-[0.9rem] text-ink-muted';
