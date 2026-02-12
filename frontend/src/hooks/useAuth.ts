import { signIn, signOut, getCurrentUser, fetchAuthSession } from 'aws-amplify/auth';
import { useAuthStore } from '../store/authStore';
import { useNavigate } from 'react-router-dom';

const getErrorMessage = (error: unknown, fallback: string): string => {
  if (error && typeof error === 'object' && 'message' in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === 'string' && message.length > 0) {
      return message;
    }
  }
  return fallback;
};

export const useAuth = () => {
  const { setAuth, logout: clearAuth, isAuthenticated, user } = useAuthStore();
  const navigate = useNavigate();

  const login = async (username: string, password: string) => {
    try {
      const { isSignedIn } = await signIn({
        username,
        password,
        options: {
          authFlowType: 'USER_PASSWORD_AUTH',
        },
      });

      if (isSignedIn) {
        // Get user info and tokens
        const currentUser = await getCurrentUser();
        const session = await fetchAuthSession();

        const idToken = session.tokens?.idToken?.toString() || '';
        const accessToken = session.tokens?.accessToken?.toString() || '';

        // Extract user info from ID token payload
        const userInfo = {
          id: currentUser.userId,
          username: currentUser.username,
          email: session.tokens?.idToken?.payload?.email as string | undefined,
        };

        setAuth(userInfo, idToken, accessToken);
        return { success: true };
      }

      return { success: false, error: 'Sign in failed' };
    } catch (error: unknown) {
      console.error('Login error:', error);
      return {
        success: false,
        error: getErrorMessage(error, 'Invalid username or password'),
      };
    }
  };

  const logout = async () => {
    try {
      await signOut();
      clearAuth();
      navigate('/login');
    } catch (error) {
      console.error('Logout error:', error);
      // Clear local state even if signOut fails
      clearAuth();
      navigate('/login');
    }
  };

  const checkAuth = async () => {
    try {
      await getCurrentUser();
      const session = await fetchAuthSession();
      return session.tokens !== undefined;
    } catch {
      return false;
    }
  };

  return {
    login,
    logout,
    checkAuth,
    isAuthenticated,
    user,
  };
};
