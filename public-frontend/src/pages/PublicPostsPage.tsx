import { Link } from 'react-router-dom';
import { usePublicPosts } from '@/hooks/usePublicPosts';
import { resolveMediaSrc } from '@/utils/media';

const formatDate = (value?: number) => {
  if (!value) return '';
  return new Date(value).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

export const PublicPostsPage = () => {
  const { data, isLoading, isError, fetchNextPage, hasNextPage, isFetchingNextPage } = usePublicPosts();

  const posts = data?.pages.flatMap((page) => page.items) ?? [];
  const [featuredPost, ...secondaryPosts] = posts;

  const getPostSummary = (content = '') => {
    const plain = content.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
    if (!plain) return 'Read the full article for more details.';
    return plain.length > 170 ? `${plain.slice(0, 170)}...` : plain;
  };

  return (
    <div className="shell">
      <header className="hero-panel animate-pop">
        <div className="hero">
          <p className="eyebrow">AWS Projects Blog</p>
          <h1>Practical stories from real AWS project builds.</h1>
          <p>Architecture notes, implementation lessons, and production-ready writeups.</p>
        </div>
      </header>

      {isLoading && <p className="state">Loading posts...</p>}
      {isError && <p className="state error">Failed to load posts.</p>}

      {!isLoading && !isError && posts.length === 0 && <p className="state">No published posts yet.</p>}

      {featuredPost && (
        <section className="featured">
          <article className="featured-card animate-rise">
            {featuredPost.mainImageKey ? (
              <img
                className="featured-image"
                src={resolveMediaSrc(featuredPost.mainImageKey)}
                alt={featuredPost.title}
                loading="lazy"
              />
            ) : (
              <div className="featured-image placeholder">Featured story</div>
            )}
            <div className="featured-body">
              <p className="meta">{formatDate(featuredPost.publishedAt || featuredPost.updatedAt)}</p>
              <h2>{featuredPost.title}</h2>
              <p className="summary">{getPostSummary(featuredPost.content)}</p>
              <Link className="read-link" to={`/posts/${featuredPost.postID}`}>
                Read featured story
              </Link>
            </div>
          </article>
        </section>
      )}

      {secondaryPosts.length > 0 && (
        <section>
          <div className="section-head">
            <h3>Latest Articles</h3>
          </div>
          <div className="grid">
            {secondaryPosts.map((post, index) => (
              <article
                className="card animate-rise"
                key={post.postID}
                style={{ animationDelay: `${Math.min(index * 70, 420)}ms` }}
              >
                {post.mainImageKey ? (
                  <img className="card-image" src={resolveMediaSrc(post.mainImageKey)} alt={post.title} loading="lazy" />
                ) : (
                  <div className="card-image placeholder">No image</div>
                )}
                <div className="card-body">
                  <p className="meta">{formatDate(post.publishedAt || post.updatedAt)}</p>
                  <h2>{post.title}</h2>
                  <p className="summary">{getPostSummary(post.content)}</p>
                  <Link className="read-link" to={`/posts/${post.postID}`}>
                    Read article
                  </Link>
                </div>
              </article>
            ))}
          </div>
        </section>
      )}

      {hasNextPage && (
        <div className="load-more-wrap">
          <button className="load-more" onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
            {isFetchingNextPage ? 'Loading...' : 'Load more'}
          </button>
        </div>
      )}
    </div>
  );
};
