import { useState, useEffect } from 'react';
import type { ReactNode } from 'react';
import { useOutlet, useLocation } from 'react-router-dom';
import { Menu } from 'lucide-react';
import Sidebar from './Sidebar';

interface LayoutProps {
  children?: ReactNode;
}

const Layout = ({ children }: LayoutProps) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const location = useLocation();
  const outlet = useOutlet();

  // ── Page crossfade ──────────────────────────────────────────────────────
  // Hold the currently-displayed page; on navigation, fade it out, then swap
  // to the new page and fade it back in.
  const [display, setDisplay] = useState({ key: location.pathname, node: outlet });
  const [stage, setStage] = useState<'in' | 'out'>('in');

  useEffect(() => {
    if (location.pathname !== display.key) {
      setStage('out');
    }
  }, [location.pathname, display.key]);

  const handleAnimationEnd = () => {
    if (stage === 'out') {
      setDisplay({ key: location.pathname, node: outlet });
      setStage('in');
    }
  };

  // Close the drawer whenever the route changes
  useEffect(() => {
    setSidebarOpen(false);
  }, [location.pathname]);

  return (
    <div className="min-h-screen bg-canvas bg-fixed [background-image:radial-gradient(900px_circle_at_100%_0%,rgba(251,146,60,0.10),transparent_55%),radial-gradient(700px_circle_at_0%_100%,rgba(249,115,22,0.07),transparent_50%)]">
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Mobile backdrop */}
      {sidebarOpen && (
        <button
          type="button"
          aria-label="Close menu"
          onClick={() => setSidebarOpen(false)}
          className="fixed inset-0 z-40 bg-black/30 lg:hidden"
        />
      )}

      <div className="lg:ml-72">
        {/* Mobile top bar with menu toggle */}
        <div className="sticky top-0 z-30 flex items-center gap-3 border-b border-edge bg-canvas/90 px-4 py-3 backdrop-blur lg:hidden">
          <button
            type="button"
            onClick={() => setSidebarOpen(true)}
            aria-label="Open menu"
            className="inline-flex items-center gap-2 rounded-xl border border-edge bg-white px-4 py-2 text-sm font-semibold text-ink shadow-sm transition-colors hover:bg-primary-light"
          >
            <Menu size={18} aria-hidden="true" /> Menu
          </button>
          <span className="font-racing text-xl uppercase tracking-[3px] text-primary">
            CARE<span className="text-ink">BIKE</span>
          </span>
        </div>

        <main className="p-4 lg:p-8">
          {children ? (
            // Explicit children (non-routed usage) — no crossfade needed
            <div className="animate-page-in">{children}</div>
          ) : (
            <div
              onAnimationEnd={handleAnimationEnd}
              className={stage === 'out' ? 'animate-page-out' : 'animate-page-in'}
            >
              {display.node}
            </div>
          )}
        </main>
      </div>
    </div>
  );
};

export default Layout;
