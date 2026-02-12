import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from '@/components/ui/sonner';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { AppLayout } from '@/components/layout/AppLayout';
import { LoginPage } from '@/pages/LoginPage';
import { DashboardPage } from '@/pages/DashboardPage';
import { PostsPage } from '@/pages/PostsPage';
import { PostCreatePage } from '@/pages/PostCreatePage';
import { PostEditPage } from '@/pages/PostEditPage';
import { PostViewPage } from '@/pages/PostViewPage';
import { LeadsPage } from '@/pages/LeadsPage';
import { NotFoundPage } from '@/pages/NotFoundPage';
import '@/utils/amplify-config';

function App() {
  return (
    <ErrorBoundary>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />

          <Route element={<ProtectedRoute />}>
            <Route element={<AppLayout />}>
              <Route path="/" element={<Navigate to="/dashboard" replace />} />
              <Route path="/dashboard" element={<DashboardPage />} />
              <Route path="/posts" element={<PostsPage />} />
              <Route path="/posts/new" element={<PostCreatePage />} />
              <Route path="/posts/:postId" element={<PostViewPage />} />
              <Route path="/posts/:postId/edit" element={<PostEditPage />} />
              <Route path="/leads" element={<LeadsPage />} />
            </Route>
          </Route>

          <Route path="*" element={<NotFoundPage />} />
        </Routes>
        <Toaster />
      </BrowserRouter>
    </ErrorBoundary>
  );
}

export default App;
