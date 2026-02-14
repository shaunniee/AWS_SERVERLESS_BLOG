import { Link, useParams } from 'react-router-dom';
import { useMemo } from 'react';
import { usePublicPost } from '@/hooks/usePublicPosts';
import { resolveMediaSrc, rewriteInlineImagesToCdn } from '@/utils/media';

export const PublicPostPage = () => {
  const { postId = '' } = useParams();
  const { data: post, isLoading, isError } = usePublicPost(postId);

  const contentHtml = useMemo(() => rewriteInlineImagesToCdn(post?.content || ''), [post?.content]);

  if (isLoading) {
    return (
      <div className="shell">
        <p className="state">Loading article...</p>
      </div>
    );
  }

  if (isError || !post) {
    return (
      <div className="shell">
        <p className="state error">Article not found.</p>
        <Link className="back-link" to="/posts">
          Back to posts
        </Link>
      </div>
    );
  }

  return (
    <main className="shell article-shell">
      <header className="article-topbar animate-pop">
        <Link className="back-link" to="/posts">
          Back to posts
        </Link>
      </header>

      <article className="article animate-rise">
        <header>
          <p className="eyebrow">Article</p>
          <h1>{post.title}</h1>
          <p className="meta">{new Date(post.publishedAt || post.updatedAt).toLocaleString()}</p>
        </header>

        {post.mainImageKey && (
          <img className="hero-image" src={resolveMediaSrc(post.mainImageKey)} alt={post.title} loading="lazy" />
        )}

        <section className="content" dangerouslySetInnerHTML={{ __html: contentHtml }} />
      </article>
    </main>
  );
};
