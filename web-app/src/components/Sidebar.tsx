import { NavLink } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard,
  Building2,
  Users,
  KeyRound,
  Wrench,
  UserCog,
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
    icon: <LayoutDashboard size={18} aria-hidden="true" />,
    label: 'Dashboard',
    roles: ['ADMIN', 'BRANCH'],
  },
  {
    to: '/staff',
    icon: <UserCog size={18} aria-hidden="true" />,
    label: 'Quản lý Nhân sự',
    roles: ['ADMIN'],
  },
  {
    to: '/branches',
    icon: <Building2 size={18} aria-hidden="true" />,
    label: 'Quản lý Chi nhánh',
    roles: ['ADMIN'],
  },
  {
    to: '/customers',
    icon: <Users size={18} aria-hidden="true" />,
    label: 'Quản lý Khách hàng',
    roles: ['ADMIN'],
  },
  {
    to: '/change-password',
    icon: <KeyRound size={18} aria-hidden="true" />,
    label: 'Đổi mật khẩu',
    roles: ['ADMIN', 'BRANCH'],
  },
];

const Sidebar = () => {
  const { user } = useAuth();
  const userRole = user?.role;

  const visibleItems = NAV_ITEMS.filter(
    (item) => userRole && (item.roles as string[]).includes(userRole),
  );

  return (
    <aside className="app-sidebar" aria-label="Menu điều hướng">
      {/* Service label */}
      <p className="app-sidebar-section-label">
        <Wrench size={12} aria-hidden="true" />
        Quản lý hệ thống
      </p>

      <ul className="app-sidebar-nav" role="list">
        {visibleItems.map((item) => (
          <li key={item.to}>
            <NavLink
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                isActive
                  ? 'app-sidebar-link app-sidebar-link--active'
                  : 'app-sidebar-link'
              }
            >
              {item.icon}
              <span>{item.label}</span>
            </NavLink>
          </li>
        ))}
      </ul>
    </aside>
  );
};

export default Sidebar;