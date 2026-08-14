-- Profile attributes upgrade
-- Run once in BOTH the development and production Supabase projects.

alter table public.profiles
  add column if not exists gender text not null default 'undisclosed',
  add column if not exists birth_date date,
  add column if not exists interests text[] not null default '{}';

alter table public.profiles
  drop constraint if exists profiles_gender_check;

alter table public.profiles
  add constraint profiles_gender_check
  check (gender in ('male', 'female', 'non_binary', 'undisclosed'));

-- Store registration fields immediately, including when email confirmation is
-- enabled and the client has not received a session yet.
create or replace function public.create_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, gender, birth_date, interests)
  values (
    new.id,
    case
      when new.raw_user_meta_data ->> 'gender' in ('male', 'female', 'non_binary', 'undisclosed')
        then new.raw_user_meta_data ->> 'gender'
      else 'undisclosed'
    end,
    nullif(new.raw_user_meta_data ->> 'birth_date', '')::date,
    coalesce(
      array(
        select jsonb_array_elements_text(
          coalesce(new.raw_user_meta_data -> 'interests', '[]'::jsonb)
        )
      ),
      '{}'::text[]
    )
  )
  on conflict (id) do update set
    gender = excluded.gender,
    birth_date = excluded.birth_date,
    interests = excluded.interests;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute procedure public.create_profile_from_auth_user();
