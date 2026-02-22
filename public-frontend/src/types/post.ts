export interface Post {
  postID: string;
  authorID: string;
  title: string;
  content: string;
  mainImageKey?: string | null;
  mediaKeys?: string[];
  status: 'PUBLISHED';
  createdAt: number;
  updatedAt: number;
  publishedAt?: number;
}

export interface PublicPostsResponse {
  items: Post[];
  nextKey: string | null;
}
