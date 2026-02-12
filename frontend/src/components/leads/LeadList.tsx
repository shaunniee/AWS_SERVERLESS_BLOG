import { useState } from 'react';
import { useLeads } from '@/hooks/useLeads';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { LeadDetails } from './LeadDetails';
import { Eye } from 'lucide-react';
import type { Lead } from '@/types/lead';

export const LeadList = () => {
  const { data: leads, isLoading, error } = useLeads();
  const [selectedLead, setSelectedLead] = useState<Lead | null>(null);

  if (isLoading) {
    return (
      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardContent className="p-6">
          <p className="text-center text-muted-foreground">Loading leads...</p>
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardContent className="p-6">
          <p className="text-center text-destructive">
            Error loading leads: {(error as Error).message}
          </p>
        </CardContent>
      </Card>
    );
  }

  if (!leads || leads.length === 0) {
    return (
      <Card className="border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <CardContent className="p-6">
          <p className="text-center text-muted-foreground">
            No leads yet. Leads submitted through your blog will appear here.
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <>
      <Card className="overflow-hidden border-white/90 shadow-[0_18px_40px_-30px_rgba(15,23,42,0.8)]">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Email</TableHead>
              <TableHead>Message</TableHead>
              <TableHead>Date</TableHead>
              <TableHead className="w-[50px]"></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {leads.map((lead) => (
              <TableRow key={lead.leadID}>
                <TableCell className="font-medium">{lead.name}</TableCell>
                <TableCell>{lead.email}</TableCell>
                <TableCell className="max-w-md truncate">
                  {lead.message}
                </TableCell>
                <TableCell>
                  {new Date(lead.createdAt).toLocaleDateString()}
                </TableCell>
                <TableCell>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => setSelectedLead(lead)}
                  >
                    <Eye className="h-4 w-4" />
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Card>

      <LeadDetails
        lead={selectedLead}
        open={!!selectedLead}
        onClose={() => setSelectedLead(null)}
      />
    </>
  );
};
