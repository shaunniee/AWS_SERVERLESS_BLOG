import { useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { PostList } from '@/components/posts/PostList';
import { Plus } from 'lucide-react';

export const PostsPage = () => {
  const navigate = useNavigate();

  return (
    <div className="page-enter space-y-6 rounded-2xl border border-white/70 bg-white/40 p-4 shadow-[0_18px_44px_-34px_rgba(15,23,42,0.8)] sm:p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold sm:text-4xl">Posts</h1>
        <Button onClick={() => navigate('/posts/new')}>
          <Plus className="mr-2 h-4 w-4" />
          Create Post
        </Button>
      </div>

      <PostList />
    </div>
  );
};
