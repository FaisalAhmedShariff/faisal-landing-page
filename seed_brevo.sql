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

-- 3. Insert default welcome and blog email templates into secrets table if not already existing
insert into public.secrets (key, value) values
('welcome_email_subject', 'Welcome!'),
('welcome_email_html', '<html><body style="font-family:sans-serif;padding:30px;line-height:1.6;color:#1a1a1a;max-width:600px;margin:0 auto;"><p>Hey there,</p><p>Thanks for subscribing! Really glad to have you here.</p><p>I will be sharing updates about ZIVO, Clyxit, building progress, sales insights and more.</p><p>Talk soon,<br/><strong>Faisal</strong></p></body></html>'),
('blog_email_subject_template', 'New post: {blog_title}'),
('blog_email_html_template', '<html><body style="font-family: sans-serif; padding: 24px; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; background-color: #f9f9f9; border: 1px solid #eee; border-radius: 8px;"><h2 style="color: #0059d1; font-size: 1.5rem; margin-top: 0;">{blog_title}</h2><p style="font-style: italic; color: #666; margin-bottom: 20px; font-size: 1.05rem;">{blog_excerpt}</p><p>I just published a new blog post on my website. You can read the full article by clicking the link below:</p><p style="margin: 32px 0; text-align: center;"><a href="{blog_link}" style="background-color: #0059d1; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">Read Full Post</a></p><hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" /><p style="font-size: 0.8rem; color: #999; text-align: center;">You received this email because you subscribed to Faisal Ahmed Shariff''s updates.</p></body></html>')
on conflict (key) do nothing;

-- 4. Create debug logs table to diagnose trigger execution issues
create table if not exists public.debug_logs (
  id uuid default uuid_generate_v4() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  message text,
  api_key_status text,
  error_detail text
);

alter table public.debug_logs enable row level security;

drop policy if exists "Allow admin read on debug_logs" on public.debug_logs;
drop policy if exists "Allow admin delete on debug_logs" on public.debug_logs;
create policy "Allow admin read on debug_logs" on public.debug_logs for select using (auth.role() = 'authenticated');
create policy "Allow admin delete on debug_logs" on public.debug_logs for delete using (auth.role() = 'authenticated');

-- 5. Add subscribers to realtime if not already added
do $$
begin
  alter publication supabase_realtime add table public.subscribers;
exception
  when duplicate_object then null;
  when others then null;
end $$;

-- 6. Enable pg_net extension
create extension if not exists pg_net;

-- 7. Welcome email trigger function with dynamic template fetching
create or replace function public.handle_new_subscriber()
returns trigger as $$
declare
  api_key text;
  sender_email text;
  sender_name text;
  email_subject text;
  email_html text;
  log_id uuid;
  post_response_id bigint;
begin
  -- Retrieve values from secrets table
  select value into api_key from public.secrets where key = 'brevo_api_key';
  select value into sender_email from public.secrets where key = 'brevo_sender_email';
  select value into sender_name from public.secrets where key = 'brevo_sender_name';
  select value into email_subject from public.secrets where key = 'welcome_email_subject';
  select value into email_html from public.secrets where key = 'welcome_email_html';
  
  if sender_email is null or sender_email = '' then sender_email := 'faisalahmedshariff@outlook.com'; end if;
  if sender_name is null or sender_name = '' then sender_name := 'Faisal Ahmed Shariff'; end if;
  if email_subject is null or email_subject = '' then email_subject := 'Welcome!'; end if;
  if email_html is null or email_html = '' then 
    email_html := '<html><body style="font-family:sans-serif;padding:30px;line-height:1.6;color:#1a1a1a;max-width:600px;margin:0 auto;"><p>Hey there,</p><p>Thanks for subscribing! Really glad to have you here.</p><p>I will be sharing updates about ZIVO, Clyxit, building progress, sales insights and more.</p><p>Talk soon,<br/><strong>Faisal</strong></p></body></html>';
  end if;

  -- Insert initial diagnostic log
  insert into public.debug_logs (message, api_key_status)
  values (
    'Trigger started for email: ' || NEW.email,
    'API Key length: ' || coalesce(length(api_key)::text, 'NULL') || 
    ', Sender: ' || coalesce(sender_email, 'NULL') || 
    ', Name: ' || coalesce(sender_name, 'NULL')
  )
  returning id into log_id;

  -- Check if API key is loaded and execute HTTP POST
  if api_key is not null and api_key <> '' then
    begin
      select net.http_post(
        url := 'https://api.brevo.com/v3/smtp/email',
        headers := jsonb_build_object(
          'accept', 'application/json',
          'content-type', 'application/json',
          'api-key', api_key
        ),
        body := jsonb_build_object(
          'sender', jsonb_build_object('name', sender_name, 'email', sender_email),
          'to', jsonb_build_array(jsonb_build_object('email', NEW.email)),
          'subject', email_subject,
          'htmlContent', email_html
        )
      ) into post_response_id;
      
      update public.debug_logs 
      set message = 'Trigger HTTP post queued successfully', 
          error_detail = 'pg_net Response Request ID: ' || coalesce(post_response_id::text, 'none')
      where id = log_id;
      
    exception when others then
      update public.debug_logs 
      set message = 'Trigger HTTP post failed inside exception block', 
          error_detail = 'SQL Error Code: ' || SQLSTATE || ' - Msg: ' || SQLERRM
      where id = log_id;
    end;
  else
    update public.debug_logs 
    set message = 'Trigger skipped: API Key is null or empty'
    where id = log_id;
  end if;
  
  return NEW;
end;
$$ language plpgsql security definer;

drop trigger if exists on_subscriber_created on public.subscribers;
create trigger on_subscriber_created
  after insert on public.subscribers
  for each row execute function public.handle_new_subscriber();

-- 8. Blog post notification RPC function with dynamic template fetching
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
  email_subject_template text;
  email_html_template text;
  email_subject text;
  email_html text;
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
  select value into email_subject_template from public.secrets where key = 'blog_email_subject_template';
  select value into email_html_template from public.secrets where key = 'blog_email_html_template';
  
  if sender_email is null or sender_email = '' then sender_email := 'faisalahmedshariff@outlook.com'; end if;
  if sender_name is null or sender_name = '' then sender_name := 'Faisal Ahmed Shariff'; end if;
  
  if email_subject_template is null or email_subject_template = '' then
    email_subject_template := 'New post: {blog_title}';
  end if;
  
  if email_html_template is null or email_html_template = '' then 
    email_html_template := '<html><body style="font-family: sans-serif; padding: 24px; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; background-color: #f9f9f9; border: 1px solid #eee; border-radius: 8px;"><h2 style="color: #0059d1; font-size: 1.5rem; margin-top: 0;">{blog_title}</h2><p style="font-style: italic; color: #666; margin-bottom: 20px; font-size: 1.05rem;">{blog_excerpt}</p><p>I just published a new blog post on my website. You can read the full article by clicking the link below:</p><p style="margin: 32px 0; text-align: center;"><a href="{blog_link}" style="background-color: #0059d1; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">Read Full Post</a></p><hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" /><p style="font-size: 0.8rem; color: #999; text-align: center;">You received this email because you subscribed to Faisal Ahmed Shariff''s updates.</p></body></html>';
  end if;

  if api_key is null or api_key = '' then
    raise exception 'Brevo API key is not configured in secrets.';
  end if;

  -- Replace placeholders in subject and body
  email_subject := replace(email_subject_template, '{blog_title}', post_title);
  email_subject := replace(email_subject, '{blog_excerpt}', post_excerpt);
  email_subject := replace(email_subject, '{blog_link}', base_url || '/blog/?post=' || post_slug);

  email_html := replace(email_html_template, '{blog_title}', post_title);
  email_html := replace(email_html, '{blog_excerpt}', post_excerpt);
  email_html := replace(email_html, '{blog_link}', base_url || '/blog/?post=' || post_slug);

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
        'subject', email_subject,
        'htmlContent', email_html
      )
    );
    sent_count := sent_count + 1;
  end loop;

  return sent_count;
end;
$$ language plpgsql security definer;

-- 9. Send test welcome email RPC function (called by Admin Dashboard)
create or replace function public.send_test_email(test_email text)
returns void as $$
declare
  api_key text;
  sender_email text;
  sender_name text;
  email_subject text;
  email_html text;
begin
  -- Ensure only authenticated admin users can call this RPC function
  if auth.role() <> 'authenticated' then
    raise exception 'Unauthorized. You must be logged in to send test emails.';
  end if;

  select value into api_key from public.secrets where key = 'brevo_api_key';
  select value into sender_email from public.secrets where key = 'brevo_sender_email';
  select value into sender_name from public.secrets where key = 'brevo_sender_name';
  select value into email_subject from public.secrets where key = 'welcome_email_subject';
  select value into email_html from public.secrets where key = 'welcome_email_html';
  
  if sender_email is null or sender_email = '' then sender_email := 'faisalahmedshariff@outlook.com'; end if;
  if sender_name is null or sender_name = '' then sender_name := 'Faisal Ahmed Shariff'; end if;
  if email_subject is null or email_subject = '' then email_subject := 'Welcome!'; end if;
  if email_html is null or email_html = '' then 
    email_html := '<html><body style="font-family:sans-serif;padding:30px;line-height:1.6;color:#1a1a1a;max-width:600px;margin:0 auto;"><p>Hey there,</p><p>Thanks for subscribing! Really glad to have you here.</p><p>I will be sharing updates about ZIVO, Clyxit, building progress, sales insights and more.</p><p>Talk soon,<br/><strong>Faisal</strong></p></body></html>';
  end if;

  if api_key is null or api_key = '' then
    raise exception 'Brevo API key is not configured in secrets.';
  end if;

  perform net.http_post(
    url := 'https://api.brevo.com/v3/smtp/email',
    headers := jsonb_build_object(
      'accept', 'application/json',
      'content-type', 'application/json',
      'api-key', api_key
    ),
    body := jsonb_build_object(
      'sender', jsonb_build_object('name', sender_name, 'email', sender_email),
      'to', jsonb_build_array(jsonb_build_object('email', test_email)),
      'subject', '[TEST] ' || email_subject,
      'htmlContent', email_html
    )
  );
end;
$$ language plpgsql security definer;
