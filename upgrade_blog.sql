-- 1. Add pinning columns to blog_posts table safely
alter table public.blog_posts add column if not exists is_pinned boolean not null default false;
alter table public.blog_posts add column if not exists pin_order integer default null;

-- 2. Update Row Level Security select policy to hide future scheduled posts
drop policy if exists "Allow public read on visible blog posts" on public.blog_posts;
create policy "Allow public read on visible blog posts" on public.blog_posts for select using (is_visible = true and published_at <= now());
