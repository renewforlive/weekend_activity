-- Recruitment lifecycle upgrade. Run once in both the production and
-- development Supabase SQL Editors.

alter table public.recruitments
  add column if not exists status text not null default 'recruiting';

alter table public.recruitments
  drop constraint if exists recruitments_status_check;

alter table public.recruitments
  add constraint recruitments_status_check
  check (status in ('recruiting', 'confirmed', 'completed', 'failed'));

-- Existing posts are still active until the expiry function classifies them.
update public.recruitments set status = 'recruiting' where status is null;

-- At one day after the scheduled meeting (or activity date if meeting time is
-- absent), confirmed groups become completed; every other active post failed.
create or replace function public.archive_expired_recruitments()
returns text language plpgsql security definer set search_path = public as $$
begin
  update public.recruitments
     set status = case when status = 'confirmed' then 'completed' else 'failed' end
   where status in ('recruiting', 'confirmed')
     and coalesce(meeting_time, activity_date) + interval '1 day' <= now();
  return 'ok';
end;
$$;

-- Only the host can confirm a group or abandon it. Confirming closes pending
-- applications, while approved members remain the confirmed group.
create or replace function public.set_recruitment_status(
  p_recruitment_id uuid,
  p_status text
) returns text language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_author uuid;
  v_current text;
begin
  if v_uid is null then return 'not_authenticated'; end if;
  if p_status not in ('confirmed', 'failed') then return 'invalid_status'; end if;

  select author_id, status into v_author, v_current
    from public.recruitments where id = p_recruitment_id;
  if v_author is null then return 'not_found'; end if;
  if v_author <> v_uid then return 'forbidden'; end if;
  if v_current <> 'recruiting' then return 'invalid_status'; end if;

  update public.recruitments set status = p_status where id = p_recruitment_id;
  if p_status = 'confirmed' then
    update public.recruitment_members
       set status = 'rejected'
     where recruitment_id = p_recruitment_id and status = 'pending';
  end if;
  return 'ok';
end;
$$;

-- A confirmed group is locked: only contact information remains editable.
create or replace function public.update_recruitment(
  p_recruitment_id uuid, p_title text, p_content text, p_headcount int,
  p_gender_pref text, p_cost int, p_activity_city text, p_activity_venue text,
  p_activity_date timestamptz, p_meeting_point text, p_meeting_time timestamptz,
  p_contact_info text
) returns text language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_author uuid; v_used int; v_status text;
begin
  if v_uid is null then return 'not_authenticated'; end if;
  select author_id, status into v_author, v_status
    from public.recruitments where id = p_recruitment_id;
  if v_author is null then return 'not_found'; end if;
  if v_author <> v_uid then return 'forbidden'; end if;
  if v_status not in ('recruiting', 'confirmed') then return 'invalid_status'; end if;

  if v_status = 'confirmed' then
    update public.recruitments set contact_info = p_contact_info
     where id = p_recruitment_id;
    return 'ok';
  end if;

  select coalesce(sum(1 + guest_count), 0) into v_used
    from public.recruitment_members
   where recruitment_id = p_recruitment_id and status <> 'rejected';
  if p_headcount < v_used then return 'headcount_too_low'; end if;
  update public.recruitments set
    title = p_title, content = p_content, headcount = p_headcount,
    gender_pref = p_gender_pref, cost = p_cost, activity_city = p_activity_city,
    activity_venue = p_activity_venue, activity_date = p_activity_date,
    meeting_point = p_meeting_point, meeting_time = p_meeting_time,
    contact_info = p_contact_info
  where id = p_recruitment_id;
  return 'ok';
end;
$$;

-- Joining stops once a group is confirmed/ended.
create or replace function public.join_recruitment(p_recruitment_id uuid, p_guest_count int default 0)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_headcount int; v_author uuid; v_used int;
  v_party int := 1 + greatest(p_guest_count, 0); v_status text;
begin
  if v_uid is null then return 'not_authenticated'; end if;
  select headcount, author_id, status into v_headcount, v_author, v_status
    from public.recruitments where id = p_recruitment_id;
  if v_headcount is null then return 'not_found'; end if;
  if v_status <> 'recruiting' then return 'invalid_status'; end if;
  if exists (select 1 from public.recruitment_members where recruitment_id = p_recruitment_id and user_id = v_uid and status <> 'rejected') then return 'ok'; end if;
  select coalesce(sum(1 + guest_count), 0) into v_used from public.recruitment_members where recruitment_id = p_recruitment_id and status <> 'rejected';
  if v_used + v_party > v_headcount then return 'full'; end if;
  insert into public.recruitment_members (recruitment_id, user_id, status, guest_count)
  values (p_recruitment_id, v_uid, case when v_uid = v_author then 'approved' else 'pending' end, v_party - 1)
  on conflict (recruitment_id, user_id) do update set status = case when v_uid = v_author then 'approved' else 'pending' end, guest_count = excluded.guest_count;
  return 'ok';
end;
$$;

-- Approved members may leave only before the host confirms the group.
create or replace function public.leave_recruitment(p_recruitment_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_status text; v_author uuid;
begin
  if v_uid is null then return 'not_authenticated'; end if;
  select status, author_id into v_status, v_author from public.recruitments where id = p_recruitment_id;
  if v_status is null then return 'not_found'; end if;
  if v_author = v_uid or v_status <> 'recruiting' then return 'invalid_status'; end if;
  delete from public.recruitment_members where recruitment_id = p_recruitment_id and user_id = v_uid;
  return 'ok';
end;
$$;

grant execute on function public.archive_expired_recruitments() to authenticated;
grant execute on function public.set_recruitment_status(uuid, text) to authenticated;
grant execute on function public.leave_recruitment(uuid) to authenticated;

-- Supabase provides pg_cron on hosted projects. This keeps expiry processing
-- running even when nobody has opened the app; the client-side RPC remains a
-- fallback for projects where the extension is unavailable.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'archive-expired-recruitments-hourly') then
      perform cron.unschedule(jobid)
        from cron.job where jobname = 'archive-expired-recruitments-hourly';
    end if;
    perform cron.schedule(
      'archive-expired-recruitments-hourly',
      '5 * * * *',
      'select public.archive_expired_recruitments();'
    );
  end if;
end;
$$;
