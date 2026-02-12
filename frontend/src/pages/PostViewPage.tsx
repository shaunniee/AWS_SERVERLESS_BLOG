import { Link, useNavigate, useParams } from 'react-router-dom';
import { usePost, usePublishPost, useUnpublishPost } from '@/hooks/usePosts';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { PostStatusBadge } from '@/components/posts/PostStatusBadge';
import { toast } from 'sonner';

export const PostViewPage = () => {
  const { postId } = useParams<{ postId: string }>();
  const navigate = useNavigate();
  const { data: post, isLoading, error } = usePost(postId!);
  const publishPost = usePublishPost();
  const unpublishPost = useUnpublishPost();

  const canEdit = post?.status === 'DRAFT' || post?.status === 'UNPUBLISHED';
  const canPublish = post?.status === 'DRAFT' || post?.status === 'UNPUBLISHED';
  const canUnpublish = post?.status === 'PUBLISHED';

  const handlePublish = async () => {
    if (!postId) return;
    try {
      await publishPost.mutateAsync(postId);
      toast.success('Post published successfully');
    } catch {
      toast.error('Failed to publish post');
    }
  };

  const handleUnpublish = async () => {
    if (!postId) return;
    try {
      await unpublishPost.mutateAsync(postId);
      toast.success('Post unpublished successfully');
    } catch {
      toast.error('Failed to unpublish post');
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

  return (
    <div className="page-enter space-y-6 rounded-2xl border border-white/70 bg-white/40 p-4 shadow-[0_18px_44px_-34px_rgba(15,23,42,0.8)] sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-3xl font-bold sm:text-4xl">{post.title}</h1>
          <div className="mt-2 flex items-center gap-3 text-sm text-muted-foreground">
            <PostStatusBadge status={post.status} />
            <span>Created {new Date(post.createdAt).toLocaleString()}</span>
            <span>Updated {new Date(post.updatedAt).toLocaleString()}</span>
          </div>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={() => navigate('/posts')}>
            Back to Posts
          </Button>
          {canPublish && (
            <Button
              variant="secondary"
              onClick={handlePublish}
              disabled={publishPost.isPending}
            >
              {publishPost.isPending ? 'Publishing...' : 'Publish'}
            </Button>
          )}
          {canUnpublish && (
            <Button
              variant="secondary"
              onClick={handleUnpublish}
              disabled={unpublishPost.isPending}
            >
              {unpublishPost.isPending ? 'Unpublishing...' : 'Unpublish'}
            </Button>
          )}
          {canEdit && (
            <Button asChild>
              <Link to={`/posts/${post.postID}/edit`}>Edit Post</Link>
            </Button>
          )}
        </div>
      </div>

      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardContent className="p-6">
          <article
            className="prose prose-slate max-w-none"
            dangerouslySetInnerHTML={{ __html: post.content }}
          />
        </CardContent>
      </Card>
    </div>
  );
};
