-- ALMAMOON FINAL: Run once in Supabase SQL Editor.
-- Public browsing; authenticated editor only. No patient records or medical details.
create extension if not exists pgcrypto;
create table if not exists public.admin_users (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create or replace function public.is_site_admin() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.admin_users where user_id = (select auth.uid()));
$$;
revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to authenticated;
create table if not exists public.site_content (
 id uuid primary key default gen_random_uuid(),
 category text not null check (category in ('news','events','doctors','clinics','services','radiology','laboratories','packages','pages','slides','faqs')),
 title text not null,
 summary text not null default '',
 body text not null default '',
 image_url text,
 link_url text,
 published boolean not null default false,
 sort_order integer not null default 0,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists site_content_category_idx on public.site_content(category,published,sort_order);
create table if not exists public.booking_requests (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(name) between 2 and 120),
 phone text not null check (char_length(phone) between 6 and 30),
 department text not null check (char_length(department) between 2 and 120),
 message text not null default '' check (char_length(message) <= 1000),
 status text not null default 'new' check (status in ('new','contacted','confirmed','cancelled')),
 created_at timestamptz not null default now()
);
create table if not exists public.contact_requests (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(name) between 2 and 120),
 phone text not null check (char_length(phone) between 6 and 30),
 kind text not null check (kind in ('feedback','job','general')),
 message text not null check (char_length(message) between 5 and 2000),
 status text not null default 'new' check (status in ('new','reviewed','closed')),
 created_at timestamptz not null default now()
);
-- Trigger prevents clients from changing booking status at creation.
create or replace function public.force_request_defaults() returns trigger
language plpgsql set search_path = '' as $$ begin
 new.status := 'new'; new.created_at := now(); return new;
end $$;
drop trigger if exists booking_defaults on public.booking_requests;
create trigger booking_defaults before insert on public.booking_requests for each row execute function public.force_request_defaults();
drop trigger if exists contact_defaults on public.contact_requests;
create trigger contact_defaults before insert on public.contact_requests for each row execute function public.force_request_defaults();
-- Restrict table privileges and enable RLS.
alter table public.admin_users enable row level security;
alter table public.site_content enable row level security;
alter table public.booking_requests enable row level security;
alter table public.contact_requests enable row level security;
revoke all on public.admin_users,public.site_content,public.booking_requests,public.contact_requests from anon,authenticated;
grant select on public.site_content to anon,authenticated;
grant insert,update,delete on public.site_content to authenticated;
grant select on public.admin_users to authenticated;
grant insert on public.booking_requests,public.contact_requests to anon,authenticated;
grant select,update,delete on public.booking_requests,public.contact_requests to authenticated;
-- Admin list can only be managed from SQL editor / service role.
drop policy if exists admin_self_read on public.admin_users;
create policy admin_self_read on public.admin_users for select to authenticated using (user_id=(select auth.uid()));
drop policy if exists public_published_content on public.site_content;
create policy public_published_content on public.site_content for select to anon,authenticated using (published or (select public.is_site_admin()));
drop policy if exists admin_insert_content on public.site_content;
create policy admin_insert_content on public.site_content for insert to authenticated with check ((select public.is_site_admin()));
drop policy if exists admin_update_content on public.site_content;
create policy admin_update_content on public.site_content for update to authenticated using ((select public.is_site_admin())) with check ((select public.is_site_admin()));
drop policy if exists admin_delete_content on public.site_content;
create policy admin_delete_content on public.site_content for delete to authenticated using ((select public.is_site_admin()));
drop policy if exists public_insert_booking on public.booking_requests;
create policy public_insert_booking on public.booking_requests for insert to anon,authenticated with check (status='new');
drop policy if exists admin_read_booking on public.booking_requests;
create policy admin_read_booking on public.booking_requests for select to authenticated using ((select public.is_site_admin()));
drop policy if exists admin_update_booking on public.booking_requests;
create policy admin_update_booking on public.booking_requests for update to authenticated using ((select public.is_site_admin())) with check ((select public.is_site_admin()));
drop policy if exists admin_delete_booking on public.booking_requests;
create policy admin_delete_booking on public.booking_requests for delete to authenticated using ((select public.is_site_admin()));
drop policy if exists public_insert_contact on public.contact_requests;
create policy public_insert_contact on public.contact_requests for insert to anon,authenticated with check (status='new');
drop policy if exists admin_read_contact on public.contact_requests;
create policy admin_read_contact on public.contact_requests for select to authenticated using ((select public.is_site_admin()));
drop policy if exists admin_update_contact on public.contact_requests;
create policy admin_update_contact on public.contact_requests for update to authenticated using ((select public.is_site_admin())) with check ((select public.is_site_admin()));
drop policy if exists admin_delete_contact on public.contact_requests;
create policy admin_delete_contact on public.contact_requests for delete to authenticated using ((select public.is_site_admin()));
-- Public image uploads are intentionally DISABLED; use dashboard Storage after verification.
-- To grant an existing Auth user access, run in SQL editor after user creation:
-- insert into public.admin_users(user_id) select id from auth.users where email='YOUR_ADMIN_EMAIL' on conflict do nothing;
