export type PostStatus = 'DRAFT' | 'PUBLISHED' | 'UNPUBLISHED' | 'ARCHIVED';

export interface Post {
  postID: string;
  authorID: string;
  title: string;
  content: string;
  status: PostStatus;
  createdAt: number;
  updatedAt: number;
  publishedAt?: number;
}

export interface CreatePostInput {
  title: string;
  content: string;
}

export interface UpdatePostInput {
  title: string;
  content: string;
}
