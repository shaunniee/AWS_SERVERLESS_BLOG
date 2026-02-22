import { useNavigate } from 'react-router-dom';
import { useCreatePost } from '@/hooks/usePosts';
import { PostForm } from '@/components/posts/PostForm';
import { toast } from 'sonner';
import type { PostFormData } from '@/utils/validators';

export const PostCreatePage = () => {
  const navigate = useNavigate();
  const createPost = useCreatePost();

  const handleSubmit = async (data: PostFormData) => {
    try {
      await createPost.mutateAsync(data);
      toast.success('Post created successfully');
      navigate('/posts');
    } catch {
      toast.error('Failed to create post');
    }
  };

  return (
    <div className="page-enter space-y-6 rounded-2xl border border-white/70 bg-white/40 p-4 shadow-[0_18px_44px_-34px_rgba(15,23,42,0.8)] sm:p-6">
      <h1 className="text-3xl font-bold sm:text-4xl">Create New Post</h1>
      <PostForm
        onSubmit={handleSubmit}
        isSubmitting={createPost.isPending}
        submitLabel="Create Post"
      />
    </div>
  );
};
