-- =====================================================================
--  Stock & costing: Supabase setup
--  Run this once in Supabase: SQL Editor > New query > paste > Run.
--  Safe to run again: it only creates what's missing.
-- =====================================================================

-- 1. Shared data. Every record in the app (materials, recipes, sales, ...)
--    is one row: its collection name, its id, and its data as JSON.
create table if not exists public.docs (
  collection text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (collection, id)
);
create index if not exists docs_collection_idx on public.docs (collection);
-- Realtime needs the full old row to report deletions.
alter table public.docs replica identity full;

-- 2. People who can sign in. A row is created automatically for each user.
--    role: 'owner' (first user), 'staff' (can record and edit), 'viewer' (read only).
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text,
  name text,
  role text not null default 'staff' check (role in ('owner', 'staff', 'viewer')),
  created_at timestamptz not null default now()
);

-- 3. Merge helper: combines two JSON objects, nested objects included.
--    Used so two devices adding entries to the same day never overwrite each other.
create or replace function public.jsonb_deep_merge(a jsonb, b jsonb)
returns jsonb language sql immutable as $$
  select case
    when jsonb_typeof(a) = 'object' and jsonb_typeof(b) = 'object' then (
      select coalesce(jsonb_object_agg(k,
        case when a ? k and b ? k then public.jsonb_deep_merge(a -> k, b -> k)
             when b ? k then b -> k
             else a -> k end), '{}'::jsonb)
      from (select jsonb_object_keys(a) as k union select jsonb_object_keys(b)) keys)
    else b
  end
$$;

-- 4. Who may change data: owners and staff, not viewers.
create or replace function public.can_write()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'staff'))
$$;

-- 5. Updating a record merges the change into what's stored.
create or replace function public.doc_merge(p_collection text, p_id text, p_patch jsonb)
returns void language plpgsql security invoker set search_path = public as $$
begin
  update public.docs
     set data = public.jsonb_deep_merge(data, p_patch), updated_at = now()
   where collection = p_collection and id = p_id;
  if not found then
    raise exception 'document not found' using errcode = 'P0002';
  end if;
end $$;

-- 6. Adds to a record, creating it first if needed, in one step.
create or replace function public.doc_upsert_merge(p_collection text, p_id text, p_patch jsonb)
returns void language sql security invoker set search_path = public as $$
  insert into public.docs (collection, id, data) values (p_collection, p_id, p_patch)
  on conflict (collection, id) do update
     set data = public.jsonb_deep_merge(public.docs.data, excluded.data), updated_at = now();
$$;

-- 7. Lets a signed-in person change their own display name.
create or replace function public.set_my_name(p_name text)
returns void language sql security definer set search_path = public as $$
  update public.profiles set name = left(trim(p_name), 80) where id = auth.uid();
$$;

-- 8. Profile row for every new user. The very first user becomes the owner.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, role)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
          case when exists (select 1 from public.profiles) then 'staff' else 'owner' end)
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Users created before this script ran also get a profile.
insert into public.profiles (id, email, name, role)
select u.id, u.email, split_part(u.email, '@', 1),
       case when row_number() over (order by u.created_at) = 1
             and not exists (select 1 from public.profiles) then 'owner' else 'staff' end
  from auth.users u
on conflict (id) do nothing;

-- 9. Security rules: only signed-in team members see anything; viewers can't change data.
alter table public.docs enable row level security;
alter table public.profiles enable row level security;

drop policy if exists "team reads data" on public.docs;
drop policy if exists "staff add data" on public.docs;
drop policy if exists "staff change data" on public.docs;
drop policy if exists "staff delete data" on public.docs;
create policy "team reads data" on public.docs for select to authenticated using (true);
create policy "staff add data" on public.docs for insert to authenticated with check (public.can_write());
create policy "staff change data" on public.docs for update to authenticated using (public.can_write()) with check (public.can_write());
create policy "staff delete data" on public.docs for delete to authenticated using (public.can_write());

drop policy if exists "team reads profiles" on public.profiles;
create policy "team reads profiles" on public.profiles for select to authenticated using (true);

revoke all on public.docs from anon;
revoke all on public.profiles from anon;
grant select, insert, update, delete on public.docs to authenticated;
grant select on public.profiles to authenticated;
revoke all on function public.doc_merge(text, text, jsonb) from public, anon;
revoke all on function public.doc_upsert_merge(text, text, jsonb) from public, anon;
revoke all on function public.set_my_name(text) from public, anon;
grant execute on function public.doc_merge(text, text, jsonb) to authenticated;
grant execute on function public.doc_upsert_merge(text, text, jsonb) to authenticated;
grant execute on function public.set_my_name(text) to authenticated;
grant execute on function public.jsonb_deep_merge(jsonb, jsonb) to authenticated;
grant execute on function public.can_write() to authenticated;

-- 10. Live updates: changes made on one device appear on the others right away.
do $$
begin
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'docs') then
    alter publication supabase_realtime add table public.docs;
  end if;
end $$;

-- Done. To make someone read-only later:
--   update public.profiles set role = 'viewer' where email = 'name@example.com';
