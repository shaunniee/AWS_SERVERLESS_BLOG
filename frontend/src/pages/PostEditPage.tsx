import { useParams, useNavigate } from 'react-router-dom';
import { usePost, useUpdatePost } from '@/hooks/usePosts';
import { PostForm } from '@/components/posts/PostForm';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { toast } from 'sonner';
import type { PostFormData } from '@/utils/validators';

export const PostEditPage = () => {
  const { postId } = useParams<{ postId: string }>();
  const navigate = useNavigate();
  const { data: post, isLoading, error } = usePost(postId!);
  const updatePost = useUpdatePost();

  const handleSubmit = async (data: PostFormData) => {
    if (!postId) return;

    try {
      await updatePost.mutateAsync({ postId, data });
      toast.success('Post updated successfully');
      navigate('/posts');
    } catch {
      toast.error('Failed to update post');
    }
  };

  if (isLoading) {
    return (
      <div className="page-enter p-6">
        <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
          <CardContent className="p-6">
            <p className="text-center text-muted-foreground">Loading post...</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (error || !post) {
    return (
      <div className="page-enter p-6">
        <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
          <CardContent className="p-6">
            <p className="text-center text-destructive">Failed to load post</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  const canEdit = post.status === 'DRAFT' || post.status === 'UNPUBLISHED';

  if (!canEdit) {
    return (
      <div className="page-enter p-6">
        <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
          <CardContent className="space-y-4 p-6">
            <p className="text-center text-muted-foreground">
              This post cannot be edited while status is <span className="font-medium">{post.status}</span>.
            </p>
            <div className="flex justify-center">
              <Button type="button" variant="outline" onClick={() => navigate(`/posts/${post.postID}`)}>
                Back to Post
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="page-enter space-y-6 rounded-2xl border border-white/70 bg-white/40 p-4 shadow-[0_18px_44px_-34px_rgba(15,23,42,0.8)] sm:p-6">
      <h1 className="text-3xl font-bold sm:text-4xl">Edit Post</h1>
      <PostForm
        defaultValues={{
          title: post.title,
          content: post.content,
          mainImageKey: post.mainImageKey || '',
          mediaKeys: post.mediaKeys || [],
        }}
        onSubmit={handleSubmit}
        isSubmitting={updatePost.isPending}
        submitLabel="Update Post"
      />
    </div>
  );
};
