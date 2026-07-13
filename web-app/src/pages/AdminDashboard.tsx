import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Client } from '@stomp/stompjs';
import {
  Building2,
  Users,
  TrendingUp,
  Clock,
  CheckCircle2,
  Wrench,
  UserCog
} from 'lucide-react';
import { btnPrimary, dashTitle, eyebrow, pageSubtitle } from '../ui/styles';

const statCard =
  'group rounded-3xl border border-edge bg-white p-6 opacity-0 animate-fade-up transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_0_25px_rgba(249,115,22,0.35)]';

const panel =
  'group relative flex flex-col gap-2.5 rounded-3xl border border-edge bg-white p-6 opacity-0 animate-fade-up transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_0_25px_rgba(249,115,22,0.35)]';

// Small note shown under each stat card
const STAT_NOTE: Record<string, string> = {
  today: 'live update',
  processing: 'system-wide',
  completed: 'this month',
  revenue: 'last 6 months',
};

// Default values for the stats
const INITIAL_STATS = [
  { id: 'today', label: "Today's services", value: 24, icon: <Wrench size={20} />, color: 'var(--color-primary)' },
  { id: 'processing', label: 'In progress', value: 15, icon: <Clock size={20} />, color: '#f59e0b' },
  { id: 'completed', label: 'Completed', value: 82, icon: <CheckCircle2 size={20} />, color: '#10b981' },
  { id: 'revenue', label: 'Monthly revenue (M₫)', value: 4.5, icon: <TrendingUp size={20} />, color: '#8b5cf6' },
];

const AdminDashboard: React.FC = () => {
  const { user } = useAuth();
  const [stats, setStats] = useState(INITIAL_STATS);

  useEffect(() => {
    const stompClient = new Client({
      brokerURL: 'ws://localhost:8080/ws',
      reconnectDelay: 5000,
      debug: (str) => console.log('STOMP (Admin):', str),
    });

    stompClient.onConnect = () => {
      console.log('Đã kết nối WebSocket thành công cho Admin!');
      stompClient.subscribe('/topic/admin/stats', (message) => {
        if (message.body) {
          setStats((prevStats) =>
            prevStats.map(stat =>
              stat.id === 'today' ? { ...stat, value: stat.value + 1 } : stat
            )
          );
        }
      });
    };

    stompClient.onStompError = (frame) => {
      console.error('Lỗi WebSocket STOMP Admin:', frame.headers['message']);
    };

    stompClient.activate();
    return () => {
      stompClient.deactivate();
    };
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
              {stat.id === 'revenue' ? `${stat.value}M₫` : stat.value}
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