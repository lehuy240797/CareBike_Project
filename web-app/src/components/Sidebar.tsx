import { NavLink, useLocation } from 'react-router-dom';
import { useRef, useState, useEffect, useLayoutEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard,
  Building2,
  Users,
  KeyRound,
  UserCog,
  Layers,
  CalendarDays,
  History,
  Wrench,
  Gauge,
  BarChart3,
} from 'lucide-react';

interface NavItem {
  to: string;
  icon: React.ReactNode;
  label: string;
  roles: ('ADMIN' | 'BRANCH')[];
}

const NAV_ITEMS: NavItem[] = [
  {
    to: '/',
    icon: <LayoutDashboard size={20} aria-hidden="true" />,
    label: 'Dashboard',
    roles: ['ADMIN', 'BRANCH'],
  },
  {
    to: '/shifts',
    icon: <CalendarDays size={18} aria-hidden="true" />,
    label: 'Shift Schedule',
    roles: ['BRANCH'],
  },
  {
    to: '/history',
    icon: <History size={18} aria-hidden="true" />,
    label: 'Request History',
    roles: ['BRANCH'],
  },
  {
    to: '/staff',
    icon: <UserCog size={20} aria-hidden="true" />,
    label: 'Branch Managers',
    roles: ['ADMIN'],
  },
  {
    to: '/branch-staff',
    icon: <Users size={20} aria-hidden="true" />,
    label: 'Mechanics',
    roles: ['BRANCH'],
  },
  {
    to: '/staff-kpi',
    icon: <BarChart3 size={20} aria-hidden="true" />,
    label: 'Mechanic KPI',
    roles: ['BRANCH'],
  },
  {
    to: '/branches',
    icon: <Building2 size={20} aria-hidden="true" />,
    label: 'Branches',
    roles: ['ADMIN'],
  },
  {
    to: '/customers',
    icon: <Users size={20} aria-hidden="true" />,
    label: 'Customers',
    roles: ['ADMIN'],
  },
  {
    to: '/categories',
    icon: <Layers size={20} aria-hidden="true" />,
    label: 'Categories',
    roles: ['ADMIN'],
  },
  {
    to: '/spare-parts',
    icon: <Wrench size={20} aria-hidden="true" />,
    label: 'Spare Parts',
    roles: ['ADMIN'],
  },
  {
    to: '/tire-specs',
    icon: <Gauge size={20} aria-hidden="true" />,
    label: 'Tire Specs',
    roles: ['ADMIN'],
  },
  {
    to: '/change-password',
    icon: <KeyRound size={20} aria-hidden="true" />,
    label: 'Change Password',
    roles: ['ADMIN', 'BRANCH'],
  },
];

interface SidebarProps {
  isOpen?: boolean;
  onClose?: () => void;
}

const Sidebar = ({ isOpen = false, onClose }: SidebarProps) => {
  const { user, logout } = useAuth();
  const userRole = user?.role;
  const { pathname } = useLocation();

  const visibleItems = NAV_ITEMS.filter(
    (item) => userRole && (item.roles as string[]).includes(userRole),
  );

  // Sliding active indicator (mirrors my-app's AdminSidebar)
  const itemRefs = useRef<(HTMLAnchorElement | null)[]>([]);
  const [indicator, setIndicator] = useState<{ top: number; height: number }>({ top: 0, height: 0 });
  const [animate, setAnimate] = useState(false);

  const activeIndex = visibleItems.findIndex((item) =>
    item.to === '/' ? pathname === '/' : pathname.startsWith(item.to),
  );

  useLayoutEffect(() => {
    const el = itemRefs.current[activeIndex];
    if (el) setIndicator({ top: el.offsetTop, height: el.offsetHeight });
  }, [activeIndex, visibleItems.length]);

  useEffect(() => {
    const id = requestAnimationFrame(() => setAnimate(true));
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <aside
      className={`fixed inset-y-0 left-0 z-50 flex h-screen w-72 flex-col overflow-y-auto border-r border-edge bg-white p-4 shadow-xl transition-transform duration-200 lg:z-40 lg:shadow-none lg:translate-x-0 ${isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      aria-label="Navigation menu"
    >
      {/* Brand */}
      <div className="mb-6 flex flex-col items-center pt-10 text-center">
        <p className="m-0 font-racing text-3xl uppercase tracking-[6px] text-primary md:text-4xl">
          CARE<span className="text-ink">BIKE</span>
        </p>
        <p className="m-0 mt-2 font-pop text-sm text-ink-muted">Admin Dashboard Panel</p>
      </div>

      {/* Nav with sliding active indicator — vertically centered to fill space */}
      <nav className="relative flex flex-1 flex-col justify-center space-y-3">
        {indicator.height > 0 && (
          <div
            className={`pointer-events-none absolute left-0 right-0 rounded-2xl bg-primary shadow-[0_0_20px_rgba(249,115,22,0.35)] ${animate ? 'transition-all duration-300 ease-out' : ''
              }`}
            style={{ top: indicator.top, height: indicator.height }}
          />
        )}

        {visibleItems.map((item, i) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            onClick={() => onClose?.()}
            ref={(el) => {
              itemRefs.current[i] = el;
            }}
            className={({ isActive }) =>
              `relative z-10 flex w-full items-center gap-3.5 rounded-2xl px-5 py-4 font-exo text-base no-underline transition-colors duration-200 [&_svg]:shrink-0 ${isActive
                ? 'font-semibold text-white [&_svg]:text-white'
                : 'font-medium text-ink hover:bg-primary-light [&_svg]:text-ink-muted'
              }`
            }
          >
            {({ isActive }) => (
              <>
                {item.icon}
                <span>{item.label}</span>
                {isActive && <span className="ml-auto h-1.5 w-1.5 rounded-full bg-white/60" />}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Log out card */}
      <button
        type="button"
        onClick={logout}
        className="group mt-8 w-full cursor-pointer rounded-3xl border border-edge bg-primary-light p-5 transition-all duration-300 hover:border-red-400 hover:bg-red-50 hover:shadow-[0_0_25px_rgba(239,68,68,0.35)]"
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="h-3 w-3 rounded-full bg-primary transition-all group-hover:bg-red-500" />
            <span className="font-semibold text-ink transition-colors group-hover:text-red-600">Log Out</span>
          </div>
          <span className="text-2xl text-primary transition-all group-hover:translate-x-1 group-hover:text-red-500">→</span>
        </div>
      </button>
    </aside>
  );
};

export default Sidebar;
