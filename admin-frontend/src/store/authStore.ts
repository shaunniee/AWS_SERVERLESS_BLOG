import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface User {
  id: string;
  email?: string;
  username: string;
}

interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  idToken: string | null;
  accessToken: string | null;
  setAuth: (user: User, idToken: string, accessToken: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      isAuthenticated: false,
      user: null,
      idToken: null,
      accessToken: null,
      setAuth: (user, idToken, accessToken) =>
        set({
          isAuthenticated: true,
          user,
          idToken,
          accessToken,
        }),
      logout: () =>
        set({
          isAuthenticated: false,
          user: null,
          idToken: null,
          accessToken: null,
        }),
    }),
    {
      name: 'auth-storage',
    }
  )
);
