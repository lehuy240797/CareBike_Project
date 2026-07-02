import { Bike, LogOut, ChevronDown } from 'lucide-react';
import { useState, useRef, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const ROLE_LABELS: Record<string, string> = {
  ADMIN: 'Administrator',
  BRANCH: 'Branch',
};

const Navbar = () => {
  const { user, logout } = useAuth();
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <nav className="app-navbar" role="navigation" aria-label="Main Navigation">
      {/* Brand */}
      <Link to="/" className="app-navbar-brand" aria-label="Go to CareBike Home">
        <span className="app-navbar-brand-icon" aria-hidden="true">
          <Bike size={20} strokeWidth={2.5} />
        </span>
        CareBike
        <span className="app-navbar-brand-suffix"> Admin</span>
      </Link>

      {/* Right side */}
      <div className="app-navbar-actions">
        {/* User dropdown */}
        <div className="app-navbar-user-menu" ref={dropdownRef}>
          <button
            type="button"
            className="app-navbar-user-btn"
            onClick={() => setDropdownOpen((o) => !o)}
            aria-haspopup="true"
            aria-expanded={dropdownOpen}
          >
            <span className="app-navbar-avatar" aria-hidden="true">
              {user?.username?.charAt(0).toUpperCase() ?? 'U'}
            </span>
            <span className="app-navbar-user-info">
              <span className="app-navbar-username">{user?.username}</span>
              <span className="app-navbar-role-badge">
                {user ? ROLE_LABELS[user.role] ?? user.role : ''}
              </span>
            </span>
            <ChevronDown
              size={16}
              className={`app-navbar-chevron ${dropdownOpen ? 'app-navbar-chevron--open' : ''}`}
            />
          </button>

          {dropdownOpen && (
            <div className="app-navbar-dropdown" role="menu">
              <Link
                to="/change-password"
                className="app-navbar-dropdown-item"
                role="menuitem"
                onClick={() => setDropdownOpen(false)}
              >
                Change Password
              </Link>
              <div className="app-navbar-dropdown-divider" />
              <button
                type="button"
                className="app-navbar-dropdown-item app-navbar-dropdown-item--danger"
                role="menuitem"
                onClick={() => {
                  setDropdownOpen(false);
                  logout();
                }}
              >
                <LogOut size={14} aria-hidden="true" />
                Log out
              </button>
            </div>
          )}
        </div>
      </div>
    </nav>
  );
};

export default Navbar;