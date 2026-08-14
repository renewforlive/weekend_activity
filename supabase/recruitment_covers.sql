-- Recruitment cover images. Run this once in both the production and
-- development Supabase SQL Editors.
--
-- Images are stored in the existing public `profile-photos` bucket under
-- `<user-id>/recruitment-covers/`, so the existing per-user storage policies
-- continue to apply.

alter table public.recruitments
  add column if not exists cover_path text;
