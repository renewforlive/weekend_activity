-- 招募功能升級:審核制 + 帶人數 + 集合資訊
--
-- 在 Supabase SQL Editor 執行一次。可重複執行(欄位/函式都做了存在檢查)。
--
-- 設計要點:
-- * 名額在「申請時」就鎖住(方案 B):待審核也佔名額,發起者不必心算。
-- * party 大小 = 1(本人)+ guest_count(帶的人)。
-- * 佔用名額 = 所有「未被拒絕」成員的 party 總和。
-- * 發起者建立招募時自動成為 approved 成員。

-- 1. recruitments:集合資訊三欄(與關聯活動的出行時間分開)
alter table public.recruitments
  add column if not exists meeting_point text,
  add column if not exists meeting_time  timestamptz,
  add column if not exists contact_info   text;

-- 2. recruitment_members:審核狀態 + 帶人數
--    既有資料預設 approved,避免升級後舊成員消失。
alter table public.recruitment_members
  add column if not exists status      text not null default 'approved',
  add column if not exists guest_count int  not null default 0;

alter table public.recruitment_members
  drop constraint if exists recruitment_members_status_check;
alter table public.recruitment_members
  add  constraint recruitment_members_status_check
       check (status in ('pending', 'approved', 'rejected'));

alter table public.recruitment_members
  drop constraint if exists recruitment_members_guest_check;
alter table public.recruitment_members
  add  constraint recruitment_members_guest_check
       check (guest_count >= 0);

-- 一人一則招募只能有一筆成員紀錄(下方 on conflict 需要此約束)。
create unique index if not exists recruitment_members_unique_pair
  on public.recruitment_members (recruitment_id, user_id);

-- 3. 申請加入:建立待審核成員,並在申請時檢查名額。
--    發起者呼叫時自動 approved;其餘為 pending。
--    重複申請(未被拒絕)視為成功,不重複佔位。
create or replace function public.join_recruitment(
  p_recruitment_id uuid,
  p_guest_count    int default 0
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_headcount int;
  v_author    uuid;
  v_used      int;
  v_party     int := 1 + greatest(p_guest_count, 0);
begin
  if v_uid is null then
    return 'not_authenticated';
  end if;

  select headcount, author_id
    into v_headcount, v_author
    from public.recruitments
   where id = p_recruitment_id;

  if v_headcount is null then
    return 'not_found';
  end if;

  -- 已是成員(未被拒絕)則視為成功,不重複佔位。
  if exists (
    select 1 from public.recruitment_members
     where recruitment_id = p_recruitment_id
       and user_id = v_uid
       and status <> 'rejected'
  ) then
    return 'ok';
  end if;

  -- 佔用名額 = 所有未被拒絕成員的 party 總和。
  select coalesce(sum(1 + guest_count), 0)
    into v_used
    from public.recruitment_members
   where recruitment_id = p_recruitment_id
     and status <> 'rejected';

  if v_used + v_party > v_headcount then
    return 'full';
  end if;

  insert into public.recruitment_members (recruitment_id, user_id, status, guest_count)
  values (
    p_recruitment_id,
    v_uid,
    case when v_uid = v_author then 'approved' else 'pending' end,
    v_party - 1
  )
  on conflict (recruitment_id, user_id) do update
    set status      = case when v_uid = v_author then 'approved' else 'pending' end,
        guest_count = excluded.guest_count;

  return 'ok';
end;
$$;

-- 4. 發起者審核成員:同意 / 拒絕。
--    只有該招募的發起者能呼叫。名額在申請時已鎖住,同意不需再檢查;
--    拒絕會自然釋出名額(排除在佔用總和之外)。
create or replace function public.set_member_status(
  p_recruitment_id uuid,
  p_user_id        uuid,
  p_status         text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_author uuid;
begin
  if v_uid is null then
    return 'not_authenticated';
  end if;
  if p_status not in ('approved', 'rejected', 'pending') then
    return 'error';
  end if;

  select author_id into v_author
    from public.recruitments
   where id = p_recruitment_id;

  if v_author is null then
    return 'not_found';
  end if;
  if v_author <> v_uid then
    return 'forbidden';
  end if;

  update public.recruitment_members
     set status = p_status
   where recruitment_id = p_recruitment_id
     and user_id = p_user_id;

  return 'ok';
end;
$$;

-- 5. 發起者更新招募內容(含集合資訊)。
--    只有發起者能改。
create or replace function public.update_recruitment(
  p_recruitment_id uuid,
  p_title          text,
  p_content        text,
  p_headcount      int,
  p_gender_pref    text,
  p_cost           int,
  p_meeting_point  text,
  p_meeting_time   timestamptz,
  p_contact_info   text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_author uuid;
  v_used   int;
begin
  if v_uid is null then
    return 'not_authenticated';
  end if;

  select author_id into v_author
    from public.recruitments
   where id = p_recruitment_id;

  if v_author is null then
    return 'not_found';
  end if;
  if v_author <> v_uid then
    return 'forbidden';
  end if;

  -- 新名額不得小於目前已佔用的名額。
  select coalesce(sum(1 + guest_count), 0)
    into v_used
    from public.recruitment_members
   where recruitment_id = p_recruitment_id
     and status <> 'rejected';

  if p_headcount < v_used then
    return 'headcount_too_low';
  end if;

  update public.recruitments
     set title         = p_title,
         content       = p_content,
         headcount     = p_headcount,
         gender_pref   = p_gender_pref,
         cost          = p_cost,
         meeting_point = p_meeting_point,
         meeting_time  = p_meeting_time,
         contact_info  = p_contact_info
   where id = p_recruitment_id;

  return 'ok';
end;
$$;