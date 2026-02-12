import { useState, useRef } from 'react';
import { useMediaUpload } from '@/hooks/useMediaUpload';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Upload, X } from 'lucide-react';
import { toast } from 'sonner';

interface MediaUploaderProps {
  open: boolean;
  onClose: () => void;
  onUploadComplete: (url: string) => void;
}

export const MediaUploader = ({ open, onClose, onUploadComplete }: MediaUploaderProps) => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [dragActive, setDragActive] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { upload, uploading, progress } = useMediaUpload();

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFile(e.dataTransfer.files[0]);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      handleFile(e.target.files[0]);
    }
  };

  const handleFile = (file: File) => {
    // Validate file type
    if (!file.type.startsWith('image/')) {
      toast.error('Please select an image file');
      return;
    }

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      toast.error('File size must be less than 5MB');
      return;
    }

    setSelectedFile(file);
  };

  const handleUpload = async () => {
    if (!selectedFile) return;

    try {
      const objectKey = await upload(selectedFile);

      // For now, return the object key as URL
      // TODO: If you have CloudFront configured, construct full URL here
      // const url = `https://your-cloudfront-domain.cloudfront.net/${objectKey}`;

      toast.success('Image uploaded successfully!');
      onUploadComplete(objectKey);
      handleClose();
    } catch (error) {
      toast.error('Failed to upload image');
      console.error('Upload error:', error);
    }
  };

  const handleClose = () => {
    setSelectedFile(null);
    setDragActive(false);
    onClose();
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(nextOpen) => {
        if (!nextOpen) handleClose();
      }}
    >
      <DialogContent className="max-h-[85vh] overflow-y-auto border-white/80 bg-white/95 shadow-[0_24px_60px_-35px_rgba(15,23,42,0.85)] backdrop-blur-md sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>Upload Image</DialogTitle>
          <DialogDescription>
            Upload an image to insert into your post (Max 5MB)
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {!selectedFile ? (
            <div
              className={`relative border-2 border-dashed rounded-lg p-8 text-center transition-colors ${
                dragActive
                  ? 'border-primary bg-primary/5'
                  : 'border-muted-foreground/25 hover:border-muted-foreground/50'
              }`}
              onDragEnter={handleDrag}
              onDragLeave={handleDrag}
              onDragOver={handleDrag}
              onDrop={handleDrop}
            >
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleChange}
                className="hidden"
              />

              <Upload className="mx-auto h-12 w-12 text-muted-foreground mb-4" />
              <p className="text-sm text-muted-foreground mb-2">
                Drag and drop an image here, or click to browse
              </p>
              <Button
                type="button"
                variant="outline"
                onClick={() => fileInputRef.current?.click()}
              >
                Choose File
              </Button>
            </div>
          ) : (
            <div className="space-y-4">
              <div className="flex items-center justify-between p-4 bg-muted rounded-lg">
                <div className="flex items-center gap-3">
                  <div className="h-12 w-12 bg-background rounded flex items-center justify-center">
                    <Upload className="h-6 w-6 text-muted-foreground" />
                  </div>
                  <div>
                    <p className="text-sm font-medium">{selectedFile.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {(selectedFile.size / 1024 / 1024).toFixed(2)} MB
                    </p>
                  </div>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  onClick={() => setSelectedFile(null)}
                  disabled={uploading}
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>

              {uploading && (
                <div className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Uploading...</span>
                    <span className="font-medium">{progress}%</span>
                  </div>
                  <div className="h-2 bg-muted rounded-full overflow-hidden">
                    <div
                      className="h-full bg-primary transition-all duration-300"
                      style={{ width: `${progress}%` }}
                    />
                  </div>
                </div>
              )}

              <div className="flex gap-2">
                <Button
                  onClick={handleUpload}
                  disabled={uploading}
                  className="flex-1"
                >
                  {uploading ? 'Uploading...' : 'Upload'}
                </Button>
                <Button
                  variant="outline"
                  onClick={handleClose}
                  disabled={uploading}
                >
                  Cancel
                </Button>
              </div>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
};
