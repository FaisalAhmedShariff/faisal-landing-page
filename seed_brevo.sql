-- 1. Create subscribers table
create table public.subscribers (
  id uuid default uuid_generate_v4() primary key,
  email text not null unique,
  subscribed_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.subscribers enable row level security;

create policy "Allow public insert on subscribers" on public.subscribers for insert with check (true);
create policy "Allow admin read on subscribers" on public.subscribers for select using (auth.role() = 'authenticated');
create policy "Allow admin delete on subscribers" on public.subscribers for delete using (auth.role() = 'authenticated');

-- 2. Create secrets table
create table public.secrets (
  key text primary key,
  value text not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.secrets enable row level security;

create policy "Allow admin all on secrets" on public.secrets for all using (auth.role() = 'authenticated');

-- 3. Add source_page column if not already there
alter table public.subscribers add column if not exists source_page text;

-- 4. Add subscribers to realtime
begin;
  alter publication supabase_realtime add table public.subscribers;
commit;

-- 5. Enable pg_net
create extension if not exists pg_net;

-- 6. Welcome email trigger function
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
  if sender_email is null then sender_email := 'faisalahmedshariff@outlook.com'; end if;
  if sender_name is null then sender_name := 'Faisal Ahmed Shariff'; end if;
  if api_key is not null and api_key <> '' then
    begin
      perform net.http_post(
        url := 'https://api.brevo.com/v3/smtp/email',
        headers := jsonb_build_object('accept','application/json','content-type','application/json','api-key',api_key),
        body := jsonb_build_object(
          'sender', jsonb_build_object('name', sender_name, 'email', sender_email),
          'to', jsonb_build_array(jsonb_build_object('email', NEW.email)),
          'subject', 'Welcome!',
          'htmlContent', '<html><body style="font-family:sans-serif;padding:30px;line-height:1.6;color:#1a1a1a;max-width:600px;margin:0 auto;"><p>Hey there,</p><p>Thanks for subscribing! Really glad to have you here.</p><p>I will be sharing updates about ZIVO, Clyxit, building progress, sales insights and more.</p><p>Talk soon,<br/><strong>Faisal</strong></p></body></html>'
        )::text
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
