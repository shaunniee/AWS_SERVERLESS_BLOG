import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { LoginForm } from '@/components/auth/LoginForm';
import { useAuthStore } from '@/store/authStore';
import { AUTH_CONFIGURED } from '@/utils/constants';

export const LoginPage = () => {
  const navigate = useNavigate();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  useEffect(() => {
    if (!AUTH_CONFIGURED || isAuthenticated) {
      navigate('/dashboard');
    }
  }, [isAuthenticated, navigate]);

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden px-4">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_20%_10%,rgba(255,214,153,0.45),transparent_32%),radial-gradient(circle_at_88%_0%,rgba(119,206,214,0.45),transparent_30%)]" />
      <LoginForm />
    </div>
  );
};
