import { useLocation } from 'react-router-dom';

const getBreadcrumbs = (pathname: string): string[] => {
  const paths = pathname.split('/').filter(Boolean);
  const breadcrumbs = ['Workspace'];

  paths.forEach((path) => {
    breadcrumbs.push(
      path
        .replace(/-/g, ' ')
        .replace(/^\w/, (char) => char.toUpperCase())
    );
  });

  return breadcrumbs;
};

export const Header = () => {
  const location = useLocation();
  const breadcrumbs = getBreadcrumbs(location.pathname);

  return (
    <header className="glass-panel mb-2 mt-2 flex h-16 items-center rounded-2xl border border-white/70 px-6 shadow-[0_12px_34px_-24px_rgba(15,23,42,0.7)]">
      <div className="flex items-center gap-2 text-sm text-muted-foreground">
        {breadcrumbs.map((crumb, index) => (
          <div key={index} className="flex items-center gap-2">
            {index > 0 && <span className="text-foreground/40">/</span>}
            <span
              className={
                index === breadcrumbs.length - 1
                  ? 'font-semibold text-foreground'
                  : 'text-foreground/60'
              }
            >
              {crumb}
            </span>
          </div>
        ))}
      </div>
    </header>
  );
};
