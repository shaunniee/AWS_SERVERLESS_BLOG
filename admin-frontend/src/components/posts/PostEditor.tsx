import { useState } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Image from '@tiptap/extension-image';
import Link from '@tiptap/extension-link';
import { Button } from '@/components/ui/button';
import { MediaUploader } from '@/components/media/MediaUploader';
import { Bold, Italic, List, ListOrdered, Heading2, Link as LinkIcon, ImageIcon } from 'lucide-react';
import { resolveMediaSrc } from '@/utils/media';

interface PostEditorProps {
  content: string;
  onChange: (content: string) => void;
  onImageUpload?: (objectKey: string) => void;
}

export const PostEditor = ({ content, onChange, onImageUpload }: PostEditorProps) => {
  const [showMediaUploader, setShowMediaUploader] = useState(false);

  const editor = useEditor({
    extensions: [
      StarterKit,
      Image.configure({
        inline: true,
        allowBase64: true,
      }),
      Link.configure({
        openOnClick: false,
      }),
    ],
    content,
    onUpdate: ({ editor }) => {
      onChange(editor.getHTML());
    },
    editorProps: {
      attributes: {
        class: 'prose prose-sm max-w-none focus:outline-none min-h-[300px] p-4',
      },
    },
  });

  const handleImageUpload = (objectKey: string) => {
    if (editor) {
      // Save object key in content; convert to full URL only when CDN is configured.
      editor.chain().focus().setImage({ src: resolveMediaSrc(objectKey) || objectKey }).run();
      onImageUpload?.(objectKey);
    }
  };

  if (!editor) {
    return null;
  }

  return (
    <>
      <div className="border rounded-lg">
        {/* Toolbar */}
        <div className="flex flex-wrap gap-1 p-2 border-b bg-muted/50">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => editor.chain().focus().toggleBold().run()}
            className={editor.isActive('bold') ? 'bg-accent' : ''}
          >
            <Bold className="h-4 w-4" />
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => editor.chain().focus().toggleItalic().run()}
            className={editor.isActive('italic') ? 'bg-accent' : ''}
          >
            <Italic className="h-4 w-4" />
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
            className={editor.isActive('heading', { level: 2 }) ? 'bg-accent' : ''}
          >
            <Heading2 className="h-4 w-4" />
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => editor.chain().focus().toggleBulletList().run()}
            className={editor.isActive('bulletList') ? 'bg-accent' : ''}
          >
            <List className="h-4 w-4" />
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => editor.chain().focus().toggleOrderedList().run()}
            className={editor.isActive('orderedList') ? 'bg-accent' : ''}
          >
            <ListOrdered className="h-4 w-4" />
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => {
              const url = window.prompt('Enter URL');
              if (url) {
                editor.chain().focus().setLink({ href: url }).run();
              }
            }}
            className={editor.isActive('link') ? 'bg-accent' : ''}
          >
            <LinkIcon className="h-4 w-4" />
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => setShowMediaUploader(true)}
            className={editor.isActive('image') ? 'bg-accent' : ''}
          >
            <ImageIcon className="h-4 w-4" />
          </Button>
        </div>

        {/* Editor Content */}
        <EditorContent editor={editor} />
      </div>

      {/* Media Uploader Dialog */}
      <MediaUploader
        open={showMediaUploader}
        onClose={() => setShowMediaUploader(false)}
        onUploadComplete={handleImageUpload}
      />
    </>
  );
};
