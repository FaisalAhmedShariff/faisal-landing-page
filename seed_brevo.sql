-- 1. Create subscribers table if not exists
create table if not exists public.subscribers (
  id uuid default uuid_generate_v4() primary key,
  email text not null unique,
  subscribed_at timestamp with time zone default timezone('utc'::text, now()) not null,
  source_page text
);

alter table public.subscribers enable row level security;

-- Recreate policies safely
drop policy if exists "Allow public insert on subscribers" on public.subscribers;
drop policy if exists "Allow admin read on subscribers" on public.subscribers;
drop policy if exists "Allow admin delete on subscribers" on public.subscribers;

create policy "Allow public insert on subscribers" on public.subscribers for insert with check (true);
create policy "Allow admin read on subscribers" on public.subscribers for select using (auth.role() = 'authenticated');
create policy "Allow admin delete on subscribers" on public.subscribers for delete using (auth.role() = 'authenticated');

-- 2. Create secrets table if not exists
create table if not exists public.secrets (
  key text primary key,
  value text not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.secrets enable row level security;

-- Recreate policies safely
drop policy if exists "Allow admin all on secrets" on public.secrets;
create policy "Allow admin all on secrets" on public.secrets for all using (auth.role() = 'authenticated');

-- 3. Add subscribers to realtime if not already added
do $$
begin
  alter publication supabase_realtime add table public.subscribers;
exception
  when duplicate_object then null;
  when others then null;
end $$;

-- 4. Enable pg_net extension
create extension if not exists pg_net;

-- 5. Welcome email trigger function
create or replace function public.handle_new_subscriber()
returns trigger as $$
declare
  api_key text;
  sender_email text;
  sender_name text;
begin
  select value into api_key from public.secrets where key = 'brevo_api_key';
  select value into sender_email from public.secrets where key = 'brevo_sender_email';
  select value into sender_name from public.secrets where key = 'brevo_sender_name';
  
  if sender_email is null or sender_email = '' then sender_email := 'faisalahmedshariff@outlook.com'; end if;
  if sender_name is null or sender_name = '' then sender_name := 'Faisal Ahmed Shariff'; end if;
  
  if api_key is not null and api_key <> '' then
    begin
      perform net.http_post(
        url := 'https://api.brevo.com/v3/smtp/email',
        headers := jsonb_build_object(
          'accept', 'application/json',
          'content-type', 'application/json',
          'api-key', api_key
        ),
        body := jsonb_build_object(
          'sender', jsonb_build_object('name', sender_name, 'email', sender_email),
          'to', jsonb_build_array(jsonb_build_object('email', NEW.email)),
          'subject', 'Welcome!',
          'htmlContent', '<html><body style="font-family:sans-serif;padding:30px;line-height:1.6;color:#1a1a1a;max-width:600px;margin:0 auto;"><p>Hey there,</p><p>Thanks for subscribing! Really glad to have you here.</p><p>I will be sharing updates about ZIVO, Clyxit, building progress, sales insights and more.</p><p>Talk soon,<br/><strong>Faisal</strong></p></body></html>'
        )
      );
    exception when others then
      raise warning 'Failed to send welcome email: %', SQLERRM;
    end;
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists on_subscriber_created on public.subscribers;
create trigger on_subscriber_created
  after insert on public.subscribers
  for each row execute function public.handle_new_subscriber();

-- 6. Blog post notification RPC function (called by Admin Dashboard securely to bypass CORS)
create or replace function public.send_blog_notification(
  post_title text,
  post_slug text,
  post_excerpt text,
  base_url text
)
returns int as $$
declare
  api_key text;
  sender_email text;
  sender_name text;
  sub record;
  sent_count int := 0;
begin
  -- Ensure only authenticated admin users can call this RPC function
  if auth.role() <> 'authenticated' then
    raise exception 'Unauthorized. You must be logged in to send notifications.';
  end if;

  select value into api_key from public.secrets where key = 'brevo_api_key';
  select value into sender_email from public.secrets where key = 'brevo_sender_email';
  select value into sender_name from public.secrets where key = 'brevo_sender_name';
  
  if sender_email is null or sender_email = '' then sender_email := 'faisalahmedshariff@outlook.com'; end if;
  if sender_name is null or sender_name = '' then sender_name := 'Faisal Ahmed Shariff'; end if;

  if api_key is null or api_key = '' then
    raise exception 'Brevo API key is not configured in secrets.';
  end if;

  for sub in select email from public.subscribers loop
    perform net.http_post(
      url := 'https://api.brevo.com/v3/smtp/email',
      headers := jsonb_build_object(
        'accept', 'application/json',
        'content-type', 'application/json',
        'api-key', api_key
      ),
      body := jsonb_build_object(
        'sender', jsonb_build_object('name', sender_name, 'email', sender_email),
        'to', jsonb_build_array(jsonb_build_object('email', sub.email)),
        'subject', 'New post: ' || post_title,
        'htmlContent', '<html><body style="font-family: sans-serif; padding: 24px; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; background-color: #f9f9f9; border: 1px solid #eee; border-radius: 8px;"><h2 style="color: #0059d1; font-size: 1.5rem; margin-top: 0;">' || post_title || '</h2><p style="font-style: italic; color: #666; margin-bottom: 20px; font-size: 1.05rem;">' || post_excerpt || '</p><p>I just published a new blog post on my website. You can read the full article by clicking the link below:</p><p style="margin: 32px 0; text-align: center;"><a href="' || base_url || '/blog/?post=' || post_slug || '" style="background-color: #0059d1; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">Read Full Post</a></p><hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" /><p style="font-size: 0.8rem; color: #999; text-align: center;">You received this email because you subscribed to Faisal Ahmed Shariff''s updates.</p></body></html>'
      )
    );
    sent_count := sent_count + 1;
  end loop;

  return sent_count;
end;
$$ language plpgsql security definer;
