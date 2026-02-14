import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { usePosts } from '@/hooks/usePosts';
import { useLeads } from '@/hooks/useLeads';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { PostStatusBadge } from '@/components/posts/PostStatusBadge';
import { Button } from '@/components/ui/button';
import { FileText, Users, Eye, Edit } from 'lucide-react';

export const DashboardPage = () => {
  const { data: posts, isLoading: postsLoading, isError: postsError } = usePosts();
  const { data: leads, isLoading: leadsLoading, isError: leadsError } = useLeads();

  const stats = useMemo(() => {
    if (!posts) return { total: 0, published: 0, drafts: 0, unpublished: 0, archived: 0 };

    return {
      total: posts.length,
      published: posts.filter(p => p.status === 'PUBLISHED').length,
      drafts: posts.filter(p => p.status === 'DRAFT').length,
      unpublished: posts.filter(p => p.status === 'UNPUBLISHED').length,
      archived: posts.filter(p => p.status === 'ARCHIVED').length,
    };
  }, [posts]);

  const recentPosts = useMemo(() => {
    if (!posts) return [];
    return [...posts]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 5);
  }, [posts]);

  const recentLeads = useMemo(() => {
    if (!leads) return [];
    return [...leads]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 5);
  }, [leads]);

  return (
    <div className="page-enter space-y-6 rounded-2xl border border-white/70 bg-white/40 p-4 shadow-[0_18px_44px_-34px_rgba(15,23,42,0.8)] sm:p-6">
      <div className="rounded-2xl border border-white/80 bg-[linear-gradient(130deg,rgba(255,255,255,0.9)_0%,rgba(227,247,244,0.8)_100%)] p-6">
        <h1 className="text-3xl font-bold sm:text-4xl">Dashboard</h1>
        <p className="mt-1 text-muted-foreground">
          Overview of your blog and lead activity
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card className="stat-card border-white/90 shadow-[0_10px_32px_-24px_rgba(15,23,42,0.7)]">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Posts</CardTitle>
            <FileText className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {postsLoading ? '-' : postsError ? 'Error' : stats.total}
            </div>
            <p className="text-xs text-muted-foreground">
              {stats.published} published
            </p>
          </CardContent>
        </Card>

        <Card className="stat-card border-white/90 shadow-[0_10px_32px_-24px_rgba(15,23,42,0.7)]">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Published</CardTitle>
            <Eye className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {postsLoading ? '-' : postsError ? 'Error' : stats.published}
            </div>
            <p className="text-xs text-muted-foreground">
              Live on your blog
            </p>
          </CardContent>
        </Card>

        <Card className="stat-card border-white/90 shadow-[0_10px_32px_-24px_rgba(15,23,42,0.7)]">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Drafts</CardTitle>
            <Edit className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {postsLoading ? '-' : postsError ? 'Error' : stats.drafts}
            </div>
            <p className="text-xs text-muted-foreground">
              In progress
            </p>
          </CardContent>
        </Card>

        <Card className="stat-card border-white/90 shadow-[0_10px_32px_-24px_rgba(15,23,42,0.7)]">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Leads</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {leadsLoading ? '-' : leadsError ? 'Error' : leads?.length ?? 0}
            </div>
            <p className="text-xs text-muted-foreground">
              Contact form submissions
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Recent Posts */}
      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle>Recent Posts</CardTitle>
            <CardDescription>Your latest blog posts</CardDescription>
          </div>
          <Button asChild variant="outline" size="sm">
            <Link to="/posts">View All</Link>
          </Button>
        </CardHeader>
        <CardContent>
          {postsLoading ? (
            <p className="text-sm text-muted-foreground">Loading posts...</p>
          ) : postsError ? (
            <p className="text-sm text-destructive">Failed to load posts</p>
          ) : recentPosts.length === 0 ? (
            <p className="text-sm text-muted-foreground">No posts yet. Create your first post!</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Title</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {recentPosts.map((post) => (
                  <TableRow key={post.postID}>
                    <TableCell className="font-medium">{post.title}</TableCell>
                    <TableCell>
                      <PostStatusBadge status={post.status} />
                    </TableCell>
                    <TableCell>
                      {new Date(post.createdAt).toLocaleDateString()}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button asChild variant="ghost" size="sm">
                        <Link to={`/posts/${post.postID}/edit`}>Edit</Link>
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Recent Leads */}
      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardHeader className="flex flex-row items-center justify-between">
          <div>
            <CardTitle>Recent Leads</CardTitle>
            <CardDescription>Latest contact form submissions</CardDescription>
          </div>
          <Button asChild variant="outline" size="sm">
            <Link to="/leads">View All</Link>
          </Button>
        </CardHeader>
        <CardContent>
          {leadsLoading ? (
            <p className="text-sm text-muted-foreground">Loading leads...</p>
          ) : leadsError ? (
            <p className="text-sm text-destructive">Failed to load leads</p>
          ) : recentLeads.length === 0 ? (
            <p className="text-sm text-muted-foreground">No leads yet.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Message</TableHead>
                  <TableHead>Date</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {recentLeads.map((lead) => (
                  <TableRow key={lead.leadID}>
                    <TableCell className="font-medium">{lead.name}</TableCell>
                    <TableCell>{lead.email}</TableCell>
                    <TableCell className="max-w-xs truncate">
                      {lead.message}
                    </TableCell>
                    <TableCell>
                      {new Date(lead.createdAt).toLocaleDateString()}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
};
