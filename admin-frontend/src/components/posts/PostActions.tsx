import { useState } from 'react';
import { MoreVertical, Edit, Trash2, Eye, EyeOff, Archive, BookOpen } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { useDeletePost, usePublishPost, useUnpublishPost, useArchivePost } from '@/hooks/usePosts';
import type { Post } from '@/types/post';
import { toast } from 'sonner';

interface PostActionsProps {
  post: Post;
}

export const PostActions = ({ post }: PostActionsProps) => {
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const navigate = useNavigate();

  const deletePost = useDeletePost();
  const publishPost = usePublishPost();
  const unpublishPost = useUnpublishPost();
  const archivePost = useArchivePost();

  const handleEdit = () => {
    navigate(`/posts/${post.postID}/edit`);
  };

  const handleView = () => {
    navigate(`/posts/${post.postID}`);
  };

  const handlePublish = async () => {
    try {
      await publishPost.mutateAsync(post.postID);
      toast.success('Post published successfully');
    } catch {
      toast.error('Failed to publish post');
    }
  };

  const handleUnpublish = async () => {
    try {
      await unpublishPost.mutateAsync(post.postID);
      toast.success('Post unpublished successfully');
    } catch {
      toast.error('Failed to unpublish post');
    }
  };

  const handleArchive = async () => {
    try {
      await archivePost.mutateAsync(post.postID);
      toast.success('Post archived successfully');
    } catch {
      toast.error('Failed to archive post');
    }
  };

  const handleDelete = async () => {
    try {
      await deletePost.mutateAsync(post.postID);
      toast.success('Post deleted successfully');
      setDeleteDialogOpen(false);
    } catch {
      toast.error('Failed to delete post');
    }
  };

  const canEdit = post.status === 'DRAFT' || post.status === 'UNPUBLISHED';
  const canPublish = post.status === 'DRAFT' || post.status === 'UNPUBLISHED';
  const canUnpublish = post.status === 'PUBLISHED';
  const canArchive = post.status !== 'ARCHIVED';

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon">
            <MoreVertical className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={handleView}>
            <BookOpen className="mr-2 h-4 w-4" />
            View
          </DropdownMenuItem>
          {canEdit && (
            <DropdownMenuItem onClick={handleEdit}>
              <Edit className="mr-2 h-4 w-4" />
              Edit
            </DropdownMenuItem>
          )}
          {canPublish && (
            <DropdownMenuItem onClick={handlePublish}>
              <Eye className="mr-2 h-4 w-4" />
              Publish
            </DropdownMenuItem>
          )}
          {canUnpublish && (
            <DropdownMenuItem onClick={handleUnpublish}>
              <EyeOff className="mr-2 h-4 w-4" />
              Unpublish
            </DropdownMenuItem>
          )}
          {canArchive && (
            <DropdownMenuItem onClick={handleArchive}>
              <Archive className="mr-2 h-4 w-4" />
              Archive
            </DropdownMenuItem>
          )}
          <DropdownMenuItem
            onClick={() => setDeleteDialogOpen(true)}
            className="text-destructive"
          >
            <Trash2 className="mr-2 h-4 w-4" />
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="border-white/80 bg-white/95 shadow-[0_24px_60px_-35px_rgba(15,23,42,0.85)] backdrop-blur-md">
          <DialogHeader>
            <DialogTitle>Delete Post</DialogTitle>
            <DialogDescription>
              Are you sure you want to delete "{post.title}"? This action cannot be
              undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleDelete}
              disabled={deletePost.isPending}
            >
              {deletePost.isPending ? 'Deleting...' : 'Delete'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
};
