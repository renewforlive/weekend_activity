-- Device token registry used by the recruitment-notifications Edge Function.
-- Run once in both the development and production Supabase projects.

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;
drop policy if exists "device tokens own select" on public.device_tokens;
drop policy if exists "device tokens own write" on public.device_tokens;
create policy "device tokens own select" on public.device_tokens
  for select to authenticated using (user_id = auth.uid());
create policy "device tokens own write" on public.device_tokens
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- A device token can belong to only one signed-in account. This function
-- atomically moves the token when the user changes account on a device.
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
