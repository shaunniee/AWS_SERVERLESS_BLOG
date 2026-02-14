import { Link } from 'react-router-dom';

export const NotFoundPage = () => {
  return (
    <div className="shell not-found animate-pop">
      <h1>404</h1>
      <p>This AWS Projects Blog page does not exist.</p>
      <Link className="back-link" to="/posts">
        Go to posts
      </Link>
    </div>
  );
};
