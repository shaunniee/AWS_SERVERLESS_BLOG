import { LeadList } from '@/components/leads/LeadList';

export const LeadsPage = () => {
  return (
    <div className="page-enter space-y-6 rounded-2xl border border-white/70 bg-white/40 p-4 shadow-[0_18px_44px_-34px_rgba(15,23,42,0.8)] sm:p-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold sm:text-4xl">Leads</h1>
          <p className="text-muted-foreground mt-1">
            View and manage leads submitted from your blog
          </p>
        </div>
      </div>

      <LeadList />
    </div>
  );
};
