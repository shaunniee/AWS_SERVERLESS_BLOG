import { NavLink } from 'react-router-dom';
import { LayoutDashboard, FileText, Mail, LogOut } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/posts', icon: FileText, label: 'Posts' },
  { to: '/leads', icon: Mail, label: 'Leads' },
];

export const Sidebar = () => {
  const { logout, user } = useAuth();

  return (
    <aside className="sticky top-2 m-2 flex h-[calc(100vh-1rem)] w-[88px] flex-shrink-0 flex-col rounded-2xl border border-white/20 bg-[linear-gradient(165deg,#12343b_0%,#1f4f57_45%,#2f6f78_100%)] text-slate-100 shadow-[0_28px_64px_-34px_rgba(15,23,42,0.85)] sm:w-72">
      {/* Logo/Brand */}
      <div className="flex h-16 items-center border-b border-white/15 px-6">
        <h1 className="text-xl font-semibold tracking-tight">
          <span className="sm:hidden">A</span>
          <span className="hidden sm:inline">Atlas Admin</span>
        </h1>
      </div>

      {/* Navigation */}
      <nav className="flex-1 space-y-1 p-4">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-200',
                isActive
                  ? 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-200/90 hover:bg-white/12 hover:text-white'
              )
            }
          >
            <item.icon className="h-5 w-5" />
            <span className="hidden sm:inline">{item.label}</span>
          </NavLink>
        ))}
      </nav>

      {/* User Section */}
      <div className="border-t border-white/15 p-4">
        <div className="mb-3 rounded-xl bg-white/10 p-3">
          <p className="text-sm font-medium text-white">
            <span className="hidden sm:inline">{user?.username || 'Admin'}</span>
            <span className="sm:hidden">Admin</span>
          </p>
          {user?.email && (
            <p className="hidden text-xs text-slate-200 sm:block">{user.email}</p>
          )}
        </div>
        <Button
          variant="outline"
          className="w-full border-white/25 bg-white/10 text-white hover:bg-white hover:text-slate-900"
          onClick={logout}
        >
          <LogOut className="mr-2 h-4 w-4" />
          <span className="hidden sm:inline">Logout</span>
        </Button>
      </div>
    </aside>
  );
};
