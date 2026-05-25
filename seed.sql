-- Seed Data for Faisal Ahmed Shariff Portfolio
-- Run this in your Supabase SQL Editor to populate the tables before testing.

-- 1. Insert Config Keys
insert into public.portfolio_config (key, value) values
('hero_name_solid', '"Faisal"'),
('hero_name_outline', '"Ahmed Shariff"'),
('hero_greeting', '"I''ve gotten your attention. Good. I''m Faisal, a 20 year old entrepreneur from Bengaluru building CRM platforms that compete with Zoho and Salesforce. Started in sales, never stopped building around it."'),
('hero_photo_url', '"assets/My picture.jpeg"'),
('about_bold_text', '"Builder.<br/>Founder.<br/>Entrepreneur."'),
('updates_title', '"Updates"'),
('connect_heading', '"Let''s work together"'),
('connect_subtext', '"Got a bold idea or just want to talk about building something serious? Hit me up."'),
('footer_copyright', '"© 2026 Faisal Ahmed Shariff"'),
('footer_location', '"Bengaluru, India"'),
('hero_socials', '[
  {"platform": "linkedin", "url": "https://www.linkedin.com/in/faisal-shariff-2b1127315", "label": "LinkedIn"},
  {"platform": "instagram", "url": "https://www.instagram.com/fa_is_al_2829?igsh=OHc5MmZ3eXpncm4=", "label": "Instagram"},
  {"platform": "github", "url": "https://github.com/FaisalAhmedShariff", "label": "GitHub"},
  {"platform": "email", "url": "mailto:faashariff2829@gmail.com", "label": "Email"}
]'),
('hero_layout', '"classic"')
on conflict (key) do update set value = excluded.value;

-- 2. Insert About Bio Paragraphs
truncate table public.about_paragraphs;
insert into public.about_paragraphs (text, sort_order) values
('I''m a 20 year old entrepreneur based in Bengaluru, India.', 0),
('Before college started I was already deep in sales, bringing in clients for three digital marketing agencies and a web development agency. No theory, no classroom. Just real conversations with real business owners, learning how they think, what they need, and how deals actually get done.', 1),
('That''s where the obsession started. I''ve met hundreds of business owners, sat across the table from people building serious companies, and realised early that the best way to learn business is to be in it.', 2),
('Now I co-lead two companies. <strong>ZIVO</strong> is an AI driven CRM competing in the space Zoho and Salesforce operate in. <strong>Clyxit</strong> is a vertical CRM built specifically for the construction and real estate industry. Both are being built by engineering teams I work closely with every day.', 3),
('I''m still a student. But everything that matters is being built outside the classroom.<br/><br/>I love connecting with founders, operators and people who are genuinely building things. If that''s you, let''s talk.', 4);

-- 3. Insert Timeline Updates
truncate table public.timeline_entries;
insert into public.timeline_entries (month, year, title, description, tags, sort_order) values
('Jul', 2023, 'Began mastering B2B sales fundamentals.', 'Cold outreach, pitch decks, negotiation. Understanding how real buying decisions get made inside organisations.', array['Sales'], 0),
('Oct', 2023, 'Started running dropservicing operations.', 'Launched a dropservicing model, onboarding the first of three digital marketing agencies. The real learning begins.', array['Operations'], 1),
('Mar', 2024, 'Scaled to managing 3 agencies + 1 web dev agency.', 'Running operations across multiple service lines. Learning cash flow, client delivery, and team coordination simultaneously.', array['Scale'], 0),
('Mid', 2024, 'Launched TheSalesDude — personal sales agency.', 'Built and ran a direct sales agency, personally driving client acquisition and pitching for service businesses.', array['Agency'], 1),
('Nov', 2024, 'Started exploring AI tooling and automation workflows.', 'Began research into how AI systems could replace manual work inside CRM pipelines and sales processes.', array['AI'], 2),
('Feb', 2025, 'Joined first highly qualified AI engineering team.', 'Began collaborating with a senior AI/ML team to prototype the ZIVO CRM intelligence layer.', array['AI Engineering'], 0),
('Jul', 2025, 'Recruited second specialised engineering team for Clyxit.', 'Onboarded a vertical software team with deep experience in real estate and construction workflows.', array['PropTech'], 1),
('Dec', 2025, 'Both products reached internal MVP milestone.', 'ZIVO and Clyxit hit their first internal milestones. Core feature sets functional, ready for early testers.', array['Milestone'], 2),
('Jan', 2026, 'ZIVO officially launched.', 'ZIVO Automations formally launched — an AI-driven CRM built to challenge Zoho and Salesforce. <a href="https://zivoautomations.com" target="_blank" style="color:var(--primary)">zivoautomations.com ↗</a>', array['Launch'], 0),
('Jan', 2026, 'Clyxit officially launched.', 'Clyxit launched as a vertical CRM purpose-built for construction and real estate. <a href="https://clyxit.com" target="_blank" style="color:var(--primary)">Clyxit.com ↗</a>', array['Launch'], 1),
('Now', 2026, 'Building. Shipping. Growing.', 'Two companies, two engineering teams, one mission: build essential software for markets that still rely on legacy tools.', array['Active'], 2);

-- 4. Insert Ventures
truncate table public.ventures;
insert into public.ventures (logo_url, name, description, website_url, year, sort_order) values
('assets/zivo logo.jpeg', 'ZIVO — AI-Driven CRM Platform', 'AI-driven CRM built to challenge legacy systems like Zoho and Salesforce.', 'https://zivoautomations.com', '2026', 0),
('', 'Clyxit — Vertical CRM for Construction & Real Estate', 'Vertical CRM purpose-built for construction and real estate industries.', 'https://clyxit.com', '2026', 1),
('', 'TheSalesDude — Sales Agency', 'Direct sales agency founded and run by Faisal focusing on client acquisition.', '', 'Founded & run by Faisal · 2024–2025', 2);

-- 5. Enable Realtime Replication for Real-time Page Updates
-- Run this in your Supabase SQL Editor to make the landing page update instantly when you modify records in the admin panel.
begin;
  -- If publication does not exist, Supabase will auto-create or you can just add tables
  alter publication supabase_realtime add table public.portfolio_config;
  alter publication supabase_realtime add table public.about_paragraphs;
  alter publication supabase_realtime add table public.timeline_entries;
  alter publication supabase_realtime add table public.ventures;
  alter publication supabase_realtime add table public.custom_sections;
commit;

-- 6. Newsletter Signups Table (Run in SQL Editor to create)
-- create table if not exists public.newsletter_signups (
--   id uuid default uuid_generate_v4() primary key,
--   email text not null,
--   source_page text not null,
--   created_at timestamp with time zone default timezone('utc'::text, now()) not null
-- );
-- alter table public.newsletter_signups enable row level security;
-- create policy "Allow public insert on newsletter" on public.newsletter_signups for insert with check (true);
-- create policy "Allow admin read/write on newsletter" on public.newsletter_signups for all using (auth.role() = 'authenticated');
-- begin;
--   alter publication supabase_realtime add table public.newsletter_signups;
-- commit;

-- 7. Page Views Visitor Tracker Table (Run in SQL Editor to create)
-- create table if not exists public.page_views (
--   id uuid default uuid_generate_v4() primary key,
--   source_page text not null,
--   created_at timestamp with time zone default timezone('utc'::text, now()) not null
-- );
-- alter table public.page_views enable row level security;
-- create policy "Allow public insert on page_views" on public.page_views for insert with check (true);
-- create policy "Allow admin read/write on page_views" on public.page_views for all using (auth.role() = 'authenticated');
-- begin;
--   alter publication supabase_realtime add table public.page_views;
-- commit;


-- 8. Blog Posts Table (Run in SQL Editor to create)
-- create table if not exists public.blog_posts (
--   id uuid default uuid_generate_v4() primary key,
--   title text not null,
--   slug text not null unique,
--   excerpt text not null,
--   content text not null,
--   is_visible boolean not null default true,
--   published_at timestamp with time zone default timezone('utc'::text, now()) not null,
--   created_at timestamp with time zone default timezone('utc'::text, now()) not null
-- );
-- alter table public.blog_posts enable row level security;
-- create policy "Allow public read on visible blog posts" on public.blog_posts for select using (is_visible = true);
-- create policy "Allow admin read/write on all blog posts" on public.blog_posts for all using (auth.role() = 'authenticated');
-- begin;
--   alter publication supabase_realtime add table public.blog_posts;
-- commit;



