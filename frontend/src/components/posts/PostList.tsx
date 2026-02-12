import { useMemo, useState } from 'react';
import { usePosts } from '@/hooks/usePosts';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { PostStatusBadge } from './PostStatusBadge';
import { PostActions } from './PostActions';
import { Card, CardContent } from '@/components/ui/card';
import { Link } from 'react-router-dom';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { POST_STATUS_LABELS } from '@/utils/constants';
import type { PostStatus } from '@/types/post';

export const PostList = () => {
  const { data: posts, isLoading, error } = usePosts();
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'ALL' | PostStatus>('ALL');

  const filteredPosts = useMemo(() => {
    if (!posts) return [];

    return posts.filter((post) => {
      const matchesStatus =
        statusFilter === 'ALL' ? true : post.status === statusFilter;
      const matchesSearch = post.title
        .toLowerCase()
        .includes(searchQuery.toLowerCase().trim());

      return matchesStatus && matchesSearch;
    });
  }, [posts, searchQuery, statusFilter]);

  if (isLoading) {
    return (
      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardContent className="p-6">
          <p className="text-center text-muted-foreground">Loading posts...</p>
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardContent className="p-6">
          <p className="text-center text-destructive">
            Error loading posts: {(error as Error).message}
          </p>
        </CardContent>
      </Card>
    );
  }

  if (!posts || posts.length === 0) {
    return (
      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardContent className="p-6">
          <p className="text-center text-muted-foreground">
            No posts yet. Create your first post!
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="overflow-hidden border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
      <CardContent className="border-b border-border/60 bg-background/40 p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search posts by title..."
            className="sm:max-w-sm"
          />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as 'ALL' | PostStatus)}
            className="h-10 rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
          >
            <option value="ALL">All statuses</option>
            <option value="DRAFT">{POST_STATUS_LABELS.DRAFT}</option>
            <option value="PUBLISHED">{POST_STATUS_LABELS.PUBLISHED}</option>
            <option value="UNPUBLISHED">{POST_STATUS_LABELS.UNPUBLISHED}</option>
            <option value="ARCHIVED">{POST_STATUS_LABELS.ARCHIVED}</option>
          </select>
          <Button
            type="button"
            variant="outline"
            onClick={() => {
              setSearchQuery('');
              setStatusFilter('ALL');
            }}
          >
            Reset
          </Button>
        </div>
      </CardContent>

      {filteredPosts.length === 0 ? (
        <CardContent className="p-6">
          <p className="text-center text-muted-foreground">
            No posts match your current filters.
          </p>
        </CardContent>
      ) : (
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Title</TableHead>
            <TableHead>Status</TableHead>
            <TableHead>Created</TableHead>
            <TableHead>Updated</TableHead>
            <TableHead className="w-[50px]"></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {filteredPosts.map((post) => (
            <TableRow key={post.postID}>
              <TableCell className="font-medium">
                <Link
                  to={`/posts/${post.postID}`}
                  className="hover:underline underline-offset-4"
                >
                  {post.title}
                </Link>
              </TableCell>
              <TableCell>
                <PostStatusBadge status={post.status} />
              </TableCell>
              <TableCell>
                {new Date(post.createdAt).toLocaleDateString()}
              </TableCell>
              <TableCell>
                {new Date(post.updatedAt).toLocaleDateString()}
              </TableCell>
              <TableCell>
                <PostActions post={post} />
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
      )}
    </Card>
  );
};
