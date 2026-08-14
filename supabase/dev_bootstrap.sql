-- Weekend Play development project bootstrap
-- Run this in the Supabase SQL Editor for the development project only.
-- It creates the application schema without copying production user data.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text default '新使用者',
  bio text default '',
  avatar_color bigint default 4282102579,
  avatar_path text,
  gender text not null default 'undisclosed' check (gender in ('male', 'female', 'non_binary', 'undisclosed')),
  birth_date date,
  interests text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text,
  emoji text,
  created_at timestamptz not null default now()
);

create table if not exists public.recruitments (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  content text not null,
  headcount int not null,
  gender_pref text not null default 'any',
  cost int not null default 0,
  activity_title text,
  activity_city text,
  activity_venue text,
  activity_date timestamptz,
  meeting_point text,
  meeting_time timestamptz,
  contact_info text,
  cover_path text,
  status text not null default 'recruiting' check (status in ('recruiting', 'confirmed', 'completed', 'failed')),
  created_at timestamptz not null default now()
);

create table if not exists public.recruitment_members (
  recruitment_id uuid not null references public.recruitments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'approved' check (status in ('pending', 'approved', 'rejected')),
  guest_count int not null default 0 check (guest_count >= 0),
  primary key (recruitment_id, user_id)
);

create table if not exists public.schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_ref text not null,
  title text not null,
  city text,
  venue text,
  activity_date timestamptz not null,
  category text,
  description text,
  cost int not null default 0,
  remind_at timestamptz not null,
  reminder_enabled boolean not null default true,
  unique (user_id, activity_ref)
);

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.profile_photos enable row level security;
alter table public.recruitments enable row level security;
alter table public.recruitment_members enable row level security;
alter table public.schedules enable row level security;
alter table public.device_tokens enable row level security;

drop policy if exists "profiles readable" on public.profiles;
drop policy if exists "profiles own write" on public.profiles;
create policy "profiles readable" on public.profiles for select to authenticated using (true);
create policy "profiles own write" on public.profiles for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "photos readable" on public.profile_photos;
drop policy if exists "photos own write" on public.profile_photos;
create policy "photos readable" on public.profile_photos for select to authenticated using (true);
create policy "photos own write" on public.profile_photos for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "recruitments readable" on public.recruitments;
drop policy if exists "recruitments own write" on public.recruitments;
create policy "recruitments readable" on public.recruitments for select to authenticated using (true);
create policy "recruitments own write" on public.recruitments for all to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());

drop policy if exists "members readable" on public.recruitment_members;
drop policy if exists "members own write" on public.recruitment_members;
create policy "members readable" on public.recruitment_members for select to authenticated using (true);
create policy "members own write" on public.recruitment_members for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "schedules own" on public.schedules;
create policy "schedules own" on public.schedules for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "device tokens own select" on public.device_tokens;
drop policy if exists "device tokens own write" on public.device_tokens;
create policy "device tokens own select" on public.device_tokens for select to authenticated using (user_id = auth.uid());
create policy "device tokens own write" on public.device_tokens for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.register_device_token(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_platform not in ('android', 'ios') then raise exception 'invalid_platform'; end if;
  delete from public.device_tokens where token = p_token;
  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, v_uid, p_platform, now());
end;
$$;

insert into storage.buckets (id, name, public)
values ('profile-photos', 'profile-photos', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "profile photos public read" on storage.objects;
drop policy if exists "profile photos own upload" on storage.objects;
drop policy if exists "profile photos own update" on storage.objects;
drop policy if exists "profile photos own delete" on storage.objects;
create policy "profile photos public read" on storage.objects for select to public using (bucket_id = 'profile-photos');
create policy "profile photos own upload" on storage.objects for insert to authenticated with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "profile photos own update" on storage.objects for update to authenticated using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "profile photos own delete" on storage.objects for delete to authenticated using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = (select auth.uid()::text));

create or replace function public.join_recruitment(p_recruitment_id uuid, p_guest_count int default 0)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_headcount int; v_author uuid; v_used int;
  v_party int := 1 + greatest(p_guest_count, 0);
begin
  if v_uid is null then return 'not_authenticated'; end if;
  select headcount, author_id into v_headcount, v_author from public.recruitments where id = p_recruitment_id;
  if v_headcount is null then return 'not_found'; end if;
  if exists (select 1 from public.recruitment_members where recruitment_id = p_recruitment_id and user_id = v_uid and status <> 'rejected') then return 'ok'; end if;
  select coalesce(sum(1 + guest_count), 0) into v_used from public.recruitment_members where recruitment_id = p_recruitment_id and status <> 'rejected';
  if v_used + v_party > v_headcount then return 'full'; end if;
  insert into public.recruitment_members (recruitment_id, user_id, status, guest_count)
  values (p_recruitment_id, v_uid, case when v_uid = v_author then 'approved' else 'pending' end, v_party - 1)
  on conflict (recruitment_id, user_id) do update set status = case when v_uid = v_author then 'approved' else 'pending' end, guest_count = excluded.guest_count;
  return 'ok';
end;
$$;

create or replace function public.set_member_status(p_recruitment_id uuid, p_user_id uuid, p_status text)
returns text language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_author uuid;
begin
  if v_uid is null then return 'not_authenticated'; end if;
  if p_status not in ('approved', 'rejected', 'pending') then return 'error'; end if;
  select author_id into v_author from public.recruitments where id = p_recruitment_id;
  if v_author is null then return 'not_found'; end if;
  if v_author <> v_uid then return 'forbidden'; end if;
  update public.recruitment_members set status = p_status where recruitment_id = p_recruitment_id and user_id = p_user_id;
  return 'ok';
end;
$$;

create or replace function public.update_recruitment(
  p_recruitment_id uuid, p_title text, p_content text, p_headcount int,
  p_gender_pref text, p_cost int, p_activity_city text, p_activity_venue text,
  p_activity_date timestamptz, p_meeting_point text, p_meeting_time timestamptz,
  p_contact_info text
) returns text language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_author uuid; v_used int;
begin
  if v_uid is null then return 'not_authenticated'; end if;
  select author_id into v_author from public.recruitments where id = p_recruitment_id;
  if v_author is null then return 'not_found'; end if;
  if v_author <> v_uid then return 'forbidden'; end if;
  select coalesce(sum(1 + guest_count), 0) into v_used from public.recruitment_members where recruitment_id = p_recruitment_id and status <> 'rejected';
  if p_headcount < v_used then return 'headcount_too_low'; end if;
  update public.recruitments set title = p_title, content = p_content, headcount = p_headcount,
    gender_pref = p_gender_pref, cost = p_cost, activity_city = p_activity_city,
    activity_venue = p_activity_venue, activity_date = p_activity_date,
    meeting_point = p_meeting_point, meeting_time = p_meeting_time, contact_info = p_contact_info
  where id = p_recruitment_id;
  return 'ok';
end;
$$;
