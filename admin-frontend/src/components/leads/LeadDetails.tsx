import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import type { Lead } from '@/types/lead';

interface LeadDetailsProps {
  lead: Lead | null;
  open: boolean;
  onClose: () => void;
}

export const LeadDetails = ({ lead, open, onClose }: LeadDetailsProps) => {
  if (!lead) return null;

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-h-[85vh] max-w-2xl overflow-y-auto border-white/80 bg-white/95 shadow-[0_24px_60px_-35px_rgba(15,23,42,0.85)] backdrop-blur-md">
        <DialogHeader>
          <DialogTitle>Lead Details</DialogTitle>
          <DialogDescription>
            Submitted on {new Date(lead.createdAt).toLocaleString()}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-2">
            <Label>Name</Label>
            <p className="text-sm">{lead.name}</p>
          </div>

          <div className="space-y-2">
            <Label>Email</Label>
            <p className="text-sm">
              <a
                href={`mailto:${lead.email}`}
                className="text-primary hover:underline"
              >
                {lead.email}
              </a>
            </p>
          </div>

          <div className="space-y-2">
            <Label>Message</Label>
            <p className="text-sm whitespace-pre-wrap rounded-lg bg-muted p-4">
              {lead.message}
            </p>
          </div>

          <div className="space-y-2">
            <Label>Status</Label>
            <p className="text-sm">{lead.status}</p>
          </div>

          <div className="space-y-2">
            <Label>Lead ID</Label>
            <p className="text-sm font-mono text-muted-foreground">
              {lead.leadID}
            </p>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};
