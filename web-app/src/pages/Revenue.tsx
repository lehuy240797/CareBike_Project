import React, { useState } from 'react';
import {
  BarChart, Bar, Cell,
  AreaChart, Area,
  XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Legend,
} from 'recharts';
import {
  TrendingUp,
  Wrench,
  Cog,
  ReceiptText,
} from 'lucide-react';
import { eyebrow, dashTitle, pageSubtitle } from '../ui/styles';

/**
 * Revenue — analytics page (DESIGN ONLY).
 * All figures below are placeholder sample data; wire them to the API later.
 */

// ── Colors ─────────────────────────────────────────────────────────────────
const PARTS_COLOR = '#8b5cf6'; // violet
const AXIS = '#a8a29e'; // stone-400 ticks
const GRID = '#f0e9e1'; // edge

// ── Sample data (placeholder — replace with API values) ────────────────────
const MONTHLY = [
  { month: 'Feb', service: 32, parts: 18 },
  { month: 'Mar', service: 41, parts: 22 },
  { month: 'Apr', service: 38, parts: 25 },
  { month: 'May', service: 52, parts: 30 },
  { month: 'Jun', service: 47, parts: 28 },
  { month: 'Jul', service: 61, parts: 35 },
];

const SERVICES = [
  { name: 'Oil change', units: 128, revenue: 38, color: '#f97316' },
  { name: 'Brake inspection', units: 96, revenue: 29, color: '#fb923c' },
  { name: 'Chain replacement', units: 74, revenue: 22, color: '#f59e0b' },
  { name: 'Tire replacement', units: 61, revenue: 19, color: '#ef4444' },
  { name: 'Full service', units: 45, revenue: 34, color: '#ec4899' },
];

const PARTS = [
  { name: 'Engine oil', units: 140, revenue: 21, color: '#8b5cf6' },
  { name: 'Brake pads', units: 88, revenue: 26, color: '#6366f1' },
  { name: 'Drive chain', units: 70, revenue: 18, color: '#3b82f6' },
  { name: 'Front tire', units: 54, revenue: 24, color: '#06b6d4' },
  { name: 'Air filter', units: 47, revenue: 9, color: '#a855f7' },
];

const BRANCHES = [
  { id: 'all', short: 'All branches', factor: 1, revenue: 289, target: 355, growth: '+9%', color: '#f97316' },
  { id: 'd1', short: 'District 1', factor: 0.34, revenue: 96, target: 110, growth: '+12%', color: '#f97316' },
  { id: 'd3', short: 'District 3', factor: 0.27, revenue: 78, target: 90, growth: '+8%', color: '#6366f1' },
  { id: 'd7', short: 'District 7', factor: 0.22, revenue: 64, target: 85, growth: '+5%', color: '#ec4899' },
  { id: 'td', short: 'Thu Duc', factor: 0.18, revenue: 51, target: 70, growth: '-3%', color: '#06b6d4' },
];

const METRICS = [
  { id: 'services', label: 'Services', icon: Wrench },
  { id: 'parts', label: 'Parts', icon: Cog },
  { id: 'revenue', label: 'Revenue', icon: TrendingUp },
] as const;
type MetricId = (typeof METRICS)[number]['id'];

const STAT_CARDS = [
  { id: 'total', label: 'Total revenue', value: '429M₫', badge: '+12%', note: 'last 6 months', icon: <TrendingUp size={18} />, color: '#f97316' },
  { id: 'service', label: 'Service revenue', value: '271M₫', badge: '+9%', note: '63% of total', icon: <Wrench size={18} />, color: '#f97316' },
  { id: 'parts', label: 'Parts revenue', value: '158M₫', badge: '+15%', note: '37% of total', icon: <Cog size={18} />, color: PARTS_COLOR },
  { id: 'orders', label: 'Paid orders', value: '512', badge: '+6%', note: 'this period', icon: <ReceiptText size={18} />, color: '#10b981' },
];

// ── Helpers ────────────────────────────────────────────────────────────────
function scaledUnits<T extends { units: number }>(base: T[], factor: number): T[] {
  return base.map((it) => ({ ...it, units: Math.max(1, Math.round(it.units * factor)) }));
}

// ── Shared class strings ───────────────────────────────────────────────────
const card = 'rounded-3xl border border-edge bg-white p-6 opacity-0 animate-fade-up';
const cardTitle = 'font-display text-lg font-black tracking-tight text-ink';

// ── Tooltips ───────────────────────────────────────────────────────────────
const CountTip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="min-w-32 rounded-2xl border border-edge bg-white p-3 text-xs shadow-xl">
      <p className="mb-2 font-bold text-ink">{label}</p>
      {payload.map((p: any, i: number) => (
        <div key={i} className="mb-1 flex items-center justify-between gap-4 last:mb-0">
          <span className="flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full" style={{ background: p.color || p.payload?.color }} />
            <span className="capitalize text-ink-muted">{p.name}</span>
          </span>
          <span className="font-bold tabular-nums text-ink">{p.value}</span>
        </div>
      ))}
    </div>
  );
};

const MoneyTip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div className="min-w-32 rounded-2xl border border-edge bg-white p-3 text-xs shadow-xl">
      <p className="mb-2 font-bold text-ink">{label}</p>
      {payload.map((p: any, i: number) => (
        <div key={i} className="mb-1 flex items-center justify-between gap-4 last:mb-0">
          <span className="flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full" style={{ background: p.color || p.payload?.color }} />
            <span className="capitalize text-ink-muted">{p.name}</span>
          </span>
          <span className="font-bold tabular-nums text-ink">{p.value}M₫</span>
        </div>
      ))}
    </div>
  );
};

const Revenue: React.FC = () => {
  const [branchId, setBranchId] = useState('all');
  const [metric, setMetric] = useState<MetricId>('services');

  const branch = BRANCHES.find((b) => b.id === branchId) ?? BRANCHES[0];
  const branchBars = BRANCHES.filter((b) => b.id !== 'all');

  const rankData = metric === 'parts' ? scaledUnits(PARTS, branch.factor) : scaledUnits(SERVICES, branch.factor);
  const maxUnits = Math.max(...rankData.map((d) => d.units));

  // Selected branch's revenue by month (derived from the monthly totals × branch share)
  const branchMonthly = MONTHLY.map((m) => ({ month: m.month, revenue: Math.round((m.service + m.parts) * branch.factor) }));
  const branchTotal = branchMonthly.reduce((s, m) => s + m.revenue, 0);
  const branchAvg = Math.round(branchTotal / branchMonthly.length);
  const branchBest = branchMonthly.reduce((a, b) => (b.revenue > a.revenue ? b : a));

  return (
    <div className="mx-auto max-w-[72rem]">
      {/* Header */}
      <div className="mb-8 animate-fade-up">
        <p className={eyebrow}>Analytics</p>
        <h1 className={`${dashTitle} mt-2`}>Revenue</h1>
        <p className={pageSubtitle}>
          Compare revenue, parts &amp; services across branches
          <span className="ml-2 inline-flex items-center gap-1 rounded-full bg-amber-50 px-2.5 py-0.5 align-middle text-[0.6875rem] font-semibold text-amber-600">
            <span className="h-1.5 w-1.5 rounded-full bg-amber-400" />
            Sample data
          </span>
        </p>
      </div>

      {/* Stat cards */}
      <div className="mb-6 grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-4">
        {STAT_CARDS.map((s, i) => (
          <div
            key={s.id}
            className="group rounded-3xl border border-edge bg-white p-6 opacity-0 animate-fade-up transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_0_25px_rgba(249,115,22,0.35)]"
            style={{ animationDelay: `${0.05 + i * 0.07}s` }}
          >
            <div className="mb-3 flex items-center justify-between">
              <p className="font-pop text-sm text-ink-muted">{s.label}</p>
              <span
                className="flex h-9 w-9 items-center justify-center rounded-xl"
                style={{ backgroundColor: `color-mix(in oklab, ${s.color} 14%, white)`, color: s.color }}
              >
                {s.icon}
              </span>
            </div>
            <h3 className="font-display text-3xl font-black tracking-tight text-ink tabular-nums">{s.value}</h3>
            <div className="mt-2 flex items-center gap-2">
              <span className="inline-flex rounded-full bg-primary-light px-2 py-0.5 text-xs font-semibold text-primary-deep">{s.badge}</span>
              <span className="text-xs text-ink-muted">{s.note}</span>
            </div>
          </div>
        ))}
      </div>

      {/* ── Interactive breakdown: row1 = branch, row2 = metric ────────────── */}
      <div className={card} style={{ animationDelay: '0.44s' }}>
        {/* Row 1 — pick a branch */}
        <div className="mb-3">
          <span className="mb-2 block font-orb text-[0.6875rem] font-semibold uppercase tracking-[2px] text-ink-muted">Branch</span>
          <div className="flex flex-wrap gap-1.5 rounded-2xl border border-edge bg-canvas/60 p-1.5">
            {BRANCHES.map((b) => (
              <button
                key={b.id}
                type="button"
                onClick={() => setBranchId(b.id)}
                className={`rounded-xl px-4 py-2 text-sm font-semibold transition-all duration-150 ${
                  branchId === b.id
                    ? 'bg-primary text-white shadow-[0_2px_10px_rgba(249,115,22,0.35)]'
                    : 'text-ink-muted hover:bg-primary-light hover:text-ink'
                }`}
              >
                {b.short}
              </button>
            ))}
          </div>
        </div>

        {/* Row 2 — pick a metric */}
        <div className="mb-6">
          <span className="mb-2 block font-orb text-[0.6875rem] font-semibold uppercase tracking-[2px] text-ink-muted">View</span>
          <div className="inline-flex gap-1.5 rounded-2xl border border-edge bg-canvas/60 p-1.5">
            {METRICS.map((m) => {
              const Icon = m.icon;
              const active = metric === m.id;
              return (
                <button
                  key={m.id}
                  type="button"
                  onClick={() => setMetric(m.id)}
                  className={`inline-flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-semibold transition-all duration-150 ${
                    active ? 'bg-ink text-white shadow-sm' : 'text-ink-muted hover:bg-primary-light hover:text-ink'
                  }`}
                >
                  <Icon size={16} />
                  {m.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Chart area — switches with the selected metric */}
        <div key={`${branchId}-${metric}`} className="animate-fade-up">
          <div className="mb-5 flex items-center justify-between">
            <h2 className={cardTitle}>
              {metric === 'services' && 'Most used services'}
              {metric === 'parts' && 'Most used parts'}
              {metric === 'revenue' && (branchId === 'all' ? 'Revenue by branch' : `${branch.short} — revenue by month`)}
            </h2>
            <span className="rounded-full bg-primary-light px-3 py-1 text-xs font-semibold text-primary-deep">{branch.short}</span>
          </div>

          {/* Services / Parts — bar chart of units + detail cards */}
          {(metric === 'services' || metric === 'parts') && (
            <div>
              <ResponsiveContainer width="100%" height={280}>
                <BarChart data={rankData}>
                  <CartesianGrid strokeDasharray="3 3" stroke={GRID} vertical={false} />
                  <XAxis dataKey="name" tick={{ fontSize: 10, fill: AXIS }} axisLine={false} tickLine={false} angle={-15} textAnchor="end" height={64} />
                  <YAxis tick={{ fontSize: 11, fill: AXIS }} axisLine={false} tickLine={false} />
                  <Tooltip content={<CountTip />} cursor={{ fill: 'rgba(249,115,22,0.06)' }} />
                  <Bar dataKey="units" name="Units used" radius={[8, 8, 0, 0]}>
                    {rankData.map((d, i) => (
                      <Cell key={i} fill={d.color} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>

              <div className="mt-6 grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
                {[...rankData].sort((a, b) => b.units - a.units).map((p, i) => (
                  <div key={p.name} className="rounded-2xl border border-edge p-4 transition-all hover:bg-primary-light">
                    <div className="mb-3 flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="h-3 w-3 shrink-0 rounded-full" style={{ background: p.color }} />
                        <span className="text-sm font-bold text-ink">{p.name}</span>
                      </div>
                      <span className="rounded-lg bg-primary-light px-2 py-1 text-xs font-bold text-primary-deep">#{i + 1}</span>
                    </div>
                    <p className="text-2xl font-black" style={{ color: p.color }}>{p.units} <span className="text-sm font-bold">used</span></p>
                    <p className="mt-1 text-xs text-ink-muted">{p.revenue}M₫ revenue</p>
                    <div className="mt-3 h-2 w-full overflow-hidden rounded-full bg-primary-light">
                      <div className="h-full rounded-full transition-all" style={{ width: `${(p.units / maxUnits) * 100}%`, background: p.color }} />
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Revenue — a specific branch: monthly revenue trend (area chart) */}
          {metric === 'revenue' && branchId !== 'all' && (
            <div>
              <div className="mb-5 grid grid-cols-3 gap-3">
                {[
                  { label: 'Total', value: `${branchTotal}M₫` },
                  { label: 'Avg / month', value: `${branchAvg}M₫` },
                  { label: 'Best month', value: `${branchBest.month} · ${branchBest.revenue}M₫` },
                ].map((s) => (
                  <div key={s.label} className="rounded-2xl border border-edge bg-canvas/50 p-3">
                    <p className="text-xs text-ink-muted">{s.label}</p>
                    <p className="mt-0.5 font-display text-lg font-black tracking-tight text-ink tabular-nums">{s.value}</p>
                  </div>
                ))}
              </div>
              <ResponsiveContainer width="100%" height={260}>
                <AreaChart data={branchMonthly} margin={{ top: 6, right: 8, left: -8, bottom: 0 }}>
                  <defs>
                    <linearGradient id="branchRev" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={branch.color} stopOpacity={0.35} />
                      <stop offset="100%" stopColor={branch.color} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke={GRID} vertical={false} />
                  <XAxis dataKey="month" tick={{ fontSize: 11, fill: AXIS }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 11, fill: AXIS }} axisLine={false} tickLine={false} tickFormatter={(v) => `${v}M`} />
                  <Tooltip content={<MoneyTip />} cursor={{ stroke: branch.color, strokeWidth: 1, strokeDasharray: '4 4' }} />
                  <Area
                    type="monotone"
                    dataKey="revenue"
                    name="Revenue"
                    stroke={branch.color}
                    strokeWidth={2.5}
                    fill="url(#branchRev)"
                    dot={{ r: 3, fill: branch.color, strokeWidth: 0 }}
                    activeDot={{ r: 5 }}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}

          {/* Revenue — all branches: colored bars per branch (revenue vs target) + detail cards */}
          {metric === 'revenue' && branchId === 'all' && (
            <div>
              <ResponsiveContainer width="100%" height={240}>
                <BarChart data={branchBars} barGap={6} barCategoryGap="35%">
                  <CartesianGrid strokeDasharray="3 3" stroke={GRID} vertical={false} />
                  <XAxis dataKey="short" tick={{ fontSize: 11, fill: AXIS }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 11, fill: AXIS }} axisLine={false} tickLine={false} tickFormatter={(v) => `${v}M`} />
                  <Tooltip content={<MoneyTip />} cursor={{ fill: 'rgba(249,115,22,0.06)' }} />
                  <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 12, paddingTop: 12 }} />
                  <Bar dataKey="revenue" name="Revenue" radius={[8, 8, 0, 0]}>
                    {branchBars.map((b, i) => (
                      <Cell key={i} fill={b.color} fillOpacity={branchId === 'all' || branchId === b.id ? 1 : 0.35} />
                    ))}
                  </Bar>
                  <Bar dataKey="target" fill="#e7e5e4" name="Target" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>

              <div className="mt-5 grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
                {branchBars.map((b) => {
                  const pct = Math.round((b.revenue / b.target) * 100);
                  return (
                    <div key={b.id} className="rounded-2xl border border-edge p-4 transition-all hover:bg-primary-light">
                      <div className="mb-2 flex items-center gap-2">
                        <span className="h-3 w-3 shrink-0 rounded-full" style={{ background: b.color }} />
                        <span className="text-sm font-bold text-ink">{b.short}</span>
                        <span className={`ml-auto text-xs font-bold ${b.growth.startsWith('+') ? 'text-green-600' : 'text-red-500'}`}>{b.growth}</span>
                      </div>
                      <p className="mb-2 text-2xl font-black" style={{ color: b.color }}>{b.revenue}M₫</p>
                      <div className="h-1.5 w-full overflow-hidden rounded-full bg-primary-light">
                        <div className="h-full rounded-full transition-all" style={{ width: `${Math.min(100, pct)}%`, background: b.color }} />
                      </div>
                      <div className="mt-1 flex justify-between text-xs text-ink-muted">
                        <span>of {b.target}M₫ target</span>
                        <span>{pct}%</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        <p className="mt-6 text-xs text-ink-muted">
          Figures are placeholders — connect to the analytics API to show live data.
        </p>
      </div>
    </div>
  );
};

export default Revenue;
