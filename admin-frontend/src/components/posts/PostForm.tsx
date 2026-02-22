import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { postSchema, type PostFormData } from '@/utils/validators';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { PostEditor } from './PostEditor';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { MediaUploader } from '@/components/media/MediaUploader';
import { extractImageKeysFromHtml } from '@/utils/media';
import { Upload, Image as ImageIcon } from 'lucide-react';

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
  const [showMainImageUploader, setShowMainImageUploader] = useState(false);
  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
  } = useForm<PostFormData>({
    resolver: zodResolver(postSchema),
    defaultValues: defaultValues || { title: '', content: '', mainImageKey: '', mediaKeys: [] },
  });

  const content = watch('content');
  const mainImageKey = watch('mainImageKey');

  const onMainImageUpload = (objectKey: string) => {
    setValue('mainImageKey', objectKey, { shouldDirty: true });
  };

  const onContentChange = (newContent: string) => {
    setValue('content', newContent, { shouldDirty: true });
    setValue('mediaKeys', extractImageKeysFromHtml(newContent), { shouldDirty: true });
  };

  const onInlineImageUpload = (objectKey: string) => {
    const contentKeys = extractImageKeysFromHtml(content || '');
    const deduped = Array.from(new Set([...contentKeys, objectKey]));
    setValue('mediaKeys', deduped, { shouldDirty: true });
  };

  const onFormSubmit = (data: PostFormData) => {
    const contentKeys = extractImageKeysFromHtml(data.content);
    const merged = Array.from(new Set([...(data.mediaKeys || []), ...contentKeys, ...(data.mainImageKey ? [data.mainImageKey] : [])]));
    return onSubmit({
      ...data,
      mediaKeys: merged,
    });
  };

  return (
    <form onSubmit={handleSubmit(onFormSubmit)} className="space-y-6">
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
              onChange={onContentChange}
              onImageUpload={onInlineImageUpload}
            />
            {errors.content && (
              <p className="text-sm text-destructive">{errors.content.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label>Main Image</Label>
            <div className="rounded-lg border border-dashed p-4">
              {mainImageKey ? (
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2 text-sm">
                    <ImageIcon className="h-4 w-4 text-muted-foreground" />
                    <span className="font-mono text-xs text-muted-foreground break-all">{mainImageKey}</span>
                  </div>
                  <div className="flex gap-2">
                    <Button type="button" variant="outline" size="sm" onClick={() => setShowMainImageUploader(true)}>
                      Replace
                    </Button>
                    <Button type="button" variant="ghost" size="sm" onClick={() => setValue('mainImageKey', '', { shouldDirty: true })}>
                      Remove
                    </Button>
                  </div>
                </div>
              ) : (
                <Button type="button" variant="outline" onClick={() => setShowMainImageUploader(true)}>
                  <Upload className="mr-2 h-4 w-4" />
                  Upload Main Image
                </Button>
              )}
            </div>
            <p className="text-xs text-muted-foreground">
              Inline and main image keys are saved with the post for future cleanup jobs.
            </p>
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

      <MediaUploader
        open={showMainImageUploader}
        onClose={() => setShowMainImageUploader(false)}
        onUploadComplete={onMainImageUpload}
      />
    </form>
  );
};
