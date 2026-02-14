import { Link, Outlet } from 'react-router-dom';

export const PublicLayout = () => {
  return (
    <div className="site-root">
      <header className="site-header">
        <div className="site-header-inner">
          <Link className="brand" to="/posts">
            <span className="brand-mark" aria-hidden="true">AWS</span>
            <span className="brand-text">AWS Projects Blog</span>
          </Link>

          <nav className="site-nav" aria-label="Main navigation">
            <Link to="/posts">All Posts</Link>
          </nav>
        </div>
      </header>

      <Outlet />

      <footer className="site-footer">
        <div className="site-footer-inner">
          <p>Built with AWS serverless services.</p>
          <Link to="/posts">Back to all posts</Link>
        </div>
      </footer>
    </div>
  );
};
