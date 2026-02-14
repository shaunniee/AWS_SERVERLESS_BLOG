import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { PublicPostPage } from '@/pages/PublicPostPage';
import { PublicPostsPage } from '@/pages/PublicPostsPage';
import { NotFoundPage } from '@/pages/NotFoundPage';
import { PublicLayout } from '@/components/PublicLayout';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<PublicLayout />}>
          <Route path="/" element={<Navigate to="/posts" replace />} />
          <Route path="/posts" element={<PublicPostsPage />} />
          <Route path="/posts/:postId" element={<PublicPostPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
