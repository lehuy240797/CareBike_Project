import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

import {
  Building2,
  Users,
  Wrench,
  UserCog,
  LayoutList
} from 'lucide-react';
import { btnPrimary, dashTitle, eyebrow, pageSubtitle } from '../ui/styles';
import apiClient from '../services/apiClient';

const statCard =
  'group rounded-3xl border border-edge bg-white p-6 opacity-0 animate-fade-up transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_0_25px_rgba(249,115,22,0.35)]';

const panel =
  'group relative flex flex-col gap-2.5 rounded-3xl border border-edge bg-white p-6 opacity-0 animate-fade-up transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_0_25px_rgba(249,115,22,0.35)]';

// Small note shown under each stat card
const STAT_NOTE: Record<string, string> = {
  branches: 'active facilities',
  customers: 'registered users',
  categories: 'service types',
  spareParts: 'inventory items',
};

// Default values for the stats
const INITIAL_STATS = [
  { id: 'branches', label: 'Total Branches', value: 0, icon: <Building2 size={20} />, color: 'var(--color-primary)' },
  { id: 'customers', label: 'Total Customers', value: 0, icon: <Users size={20} />, color: '#f59e0b' },
  { id: 'categories', label: 'Total Categories', value: 0, icon: <LayoutList size={20} />, color: '#10b981' },
  { id: 'spareParts', label: 'Total Spare Parts', value: 0, icon: <Wrench size={20} />, color: '#8b5cf6' },
];

const AdminDashboard: React.FC = () => {
  const { user } = useAuth();
  const [stats, setStats] = useState(INITIAL_STATS);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const response = await apiClient.get('/admin/stats');
        setStats([
          { id: 'branches', label: 'Total Branches', value: response.data.branches || 0, icon: <Building2 size={20} />, color: 'var(--color-primary)' },
          { id: 'customers', label: 'Total Customers', value: response.data.customers || 0, icon: <Users size={20} />, color: '#f59e0b' },
          { id: 'categories', label: 'Total Categories', value: response.data.categories || 0, icon: <LayoutList size={20} />, color: '#10b981' },
          { id: 'spareParts', label: 'Total Spare Parts', value: response.data.spareParts || 0, icon: <Wrench size={20} />, color: '#8b5cf6' },
        ]);
      } catch (error) {
        console.error('Failed to fetch admin stats:', error);
      }
    };

    fetchStats();
    // Poll every 5 seconds for live updates
    const intervalId = setInterval(fetchStats, 5000);

    return () => clearInterval(intervalId);
  }, []);

  return (
    <div className="mx-auto max-w-[72rem]">
      <div className="mb-10 animate-fade-up">
        <p className={eyebrow}>Overview</p>
        <h1 className={`${dashTitle} mt-2`}>Welcome, Admin {user?.username ?? ''} 👋</h1>
        <p className={pageSubtitle}>CareBike system overview</p>
      </div>

      {/* Stats grid real-time */}
      <div className="mb-8 grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((stat, i) => (
          <div className={statCard} key={stat.id} style={{ animationDelay: `${0.05 + i * 0.08}s` }}>
            <p className="mb-2 font-pop text-sm text-ink-muted">{stat.label}</p>
            <h3 className="mb-3 font-display text-4xl font-black tracking-tight text-ink tabular-nums">
              {stat.value}
            </h3>
            <div className="flex items-center gap-2">
              <span className="inline-flex items-center gap-1 rounded-full bg-primary-light px-3 py-1 text-xs font-semibold text-primary">
                <span className="h-1.5 w-1.5 rounded-full bg-primary animate-pulse" />
                live
              </span>
              <span className="text-xs text-ink-muted">{STAT_NOTE[stat.id]}</span>
            </div>
          </div>
        ))}
      </div>

      <h2 className="mb-4 mt-10 font-display text-xl font-black tracking-tight text-ink">
        Quick Management
      </h2>
      <div className="grid gap-4 [grid-template-columns:repeat(auto-fill,minmax(280px,1fr))]">
        <div className={panel} style={{ animationDelay: '0.18s' }}>
          <div className="flex items-center gap-2 text-primary [&_svg]:transition-transform [&_svg]:duration-300 [&_svg]:ease-spring group-hover:[&_svg]:-rotate-6 group-hover:[&_svg]:scale-110">
            <UserCog size={20} aria-hidden="true" />
            <h3 className="m-0 text-base font-semibold text-ink">Staff Accounts</h3>
          </div>
          <p className="m-0 flex-1 text-[0.9375rem] leading-relaxed text-ink-muted">
            Create accounts and grant access to branch managers.
          </p>
          <Link to="/staff" className={`${btnPrimary} mt-2 self-start`}>
            Go to Staff Management
          </Link>
        </div>

        <div className={panel} style={{ animationDelay: '0.28s' }}>
          <div className="flex items-center gap-2 text-primary [&_svg]:transition-transform [&_svg]:duration-300 [&_svg]:ease-spring group-hover:[&_svg]:-rotate-6 group-hover:[&_svg]:scale-110">
            <Building2 size={20} aria-hidden="true" />
            <h3 className="m-0 text-base font-semibold text-ink">Facilities</h3>
          </div>
          <p className="m-0 flex-1 text-[0.9375rem] leading-relaxed text-ink-muted">
            Manage physical branches and assign managers.
          </p>
          <Link to="/branches" className={`${btnPrimary} mt-2 self-start`}>
            Go to Branch Management
          </Link>
        </div>

        <div className={panel} style={{ animationDelay: '0.38s' }}>
          <div className="flex items-center gap-2 text-primary [&_svg]:transition-transform [&_svg]:duration-300 [&_svg]:ease-spring group-hover:[&_svg]:-rotate-6 group-hover:[&_svg]:scale-110">
            <Users size={20} aria-hidden="true" />
            <h3 className="m-0 text-base font-semibold text-ink">Customer Accounts</h3>
          </div>
          <p className="m-0 flex-1 text-[0.9375rem] leading-relaxed text-ink-muted">
            View app users and their maintenance history.
          </p>
          <Link to="/customers" className={`${btnPrimary} mt-2 self-start`}>
            Go to Customer Management
          </Link>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;