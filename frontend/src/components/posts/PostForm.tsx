import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { postSchema, type PostFormData } from '@/utils/validators';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { PostEditor } from './PostEditor';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

interface PostFormProps {
  defaultValues?: Partial<PostFormData>;
  onSubmit: (data: PostFormData) => Promise<void>;
  isSubmitting?: boolean;
  submitLabel?: string;
}

export const PostForm = ({
  defaultValues,
  onSubmit,
  isSubmitting,
  submitLabel = 'Save',
}: PostFormProps) => {
  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
  } = useForm<PostFormData>({
    resolver: zodResolver(postSchema),
    defaultValues: defaultValues || { title: '', content: '' },
  });

  const content = watch('content');

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Post Details</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Title */}
          <div className="space-y-2">
            <Label htmlFor="title">Title</Label>
            <Input
              id="title"
              {...register('title')}
              placeholder="Enter post title"
              disabled={isSubmitting}
            />
            {errors.title && (
              <p className="text-sm text-destructive">{errors.title.message}</p>
            )}
          </div>

          {/* Content */}
          <div className="space-y-2">
            <Label htmlFor="content">Content</Label>
            <PostEditor
              content={content || ''}
              onChange={(newContent) => setValue('content', newContent)}
            />
            {errors.content && (
              <p className="text-sm text-destructive">{errors.content.message}</p>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Actions */}
      <div className="flex gap-2">
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? 'Saving...' : submitLabel}
        </Button>
        <Button
          type="button"
          variant="outline"
          onClick={() => window.history.back()}
          disabled={isSubmitting}
        >
          Cancel
        </Button>
      </div>
    </form>
  );
};
