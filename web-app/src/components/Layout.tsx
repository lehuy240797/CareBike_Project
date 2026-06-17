import type { ReactNode } from 'react';
import { Outlet } from 'react-router-dom';
import Navbar from './Navbar';
import Sidebar from './Sidebar';

interface LayoutProps {
  children?: ReactNode;
}

const Layout = ({ children }: LayoutProps) => {
  return (
    <div className="app-layout">
      <Navbar />
      <div className="app-body">
        <Sidebar />
        <main className="app-main">
          {/* Support both children prop and <Outlet /> for nested routes */}
          {children ?? <Outlet />}
        </main>
      </div>
    </div>
  );
};

export default Layout;
