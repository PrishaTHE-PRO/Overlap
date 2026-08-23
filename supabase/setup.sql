-- Overlap: everything the app needs, in one go.
--
-- Safe to run as many times as you like. Every statement either checks first
-- or drops what it is about to create, so a second run changes nothing and
-- errors on nothing.
--
-- Supabase dashboard -> SQL Editor -> New query -> paste all of this -> Run.
-- The editor runs it as one transaction: if any line fails the whole thing is
-- rolled back, so a failure means nothing was applied, not some of it.

-- ---------------------------------------------------------------- rosters --
-- Everyone you added from a screenshot, kept against your own account so it
-- follows you between devices. Private: yours to read, nobody else's.

create table if not exists public.rosters (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  people     jsonb       not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.rosters enable row level security;

drop policy if exists "own roster only" on public.rosters;
create policy "own roster only" on public.rosters
  for all to authenticated
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ------------------------------------------------- reading group membership --
-- The group filters need to know which group each person came from. A policy
-- on group_members that queries group_members recurses, so the check goes
-- through a security definer function instead.

create or replace function public.is_group_member(g uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = g and user_id = auth.uid()
  );
$$;

revoke all     on function public.is_group_member(uuid) from public;
grant  execute on function public.is_group_member(uuid) to authenticated;

drop policy if exists "see members of your groups" on public.group_members;
create policy "see members of your groups" on public.group_members
  for select to authenticated
  using (public.is_group_member(group_id));

-- ----------------------------------------------------------- group guests --
-- People you added and chose to share with a group. They have no account, so
-- they can never be group_members; a copy of the schedule lives here instead.

create table if not exists public.group_guests (
  group_id   uuid        not null references public.groups (id) on delete cascade,
  added_by   uuid        not null references auth.users (id)    on delete cascade,
  person_id  text        not null,
  person     jsonb       not null,
  updated_at timestamptz not null default now(),
  primary key (group_id, added_by, person_id)
);

alter table public.group_guests enable row level security;

drop policy if exists "group can read guests" on public.group_guests;
create policy "group can read guests" on public.group_guests
  for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists "adder manages guests" on public.group_guests;
create policy "adder manages guests" on public.group_guests
  for all to authenticated
  using      (added_by = auth.uid())
  with check (added_by = auth.uid() and public.is_group_member(group_id));

-- --------------------------------------------------- leaving and deleting --
-- Without these, Postgres refuses the delete and PostgREST reports it as a
-- success that removed nothing, so the buttons look broken and say nothing.

drop policy if exists "leave a group" on public.group_members;
create policy "leave a group" on public.group_members
  for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists "owner deletes group" on public.groups;
create policy "owner deletes group" on public.groups
  for delete to authenticated
  using (owner = auth.uid());

-- The owner may rename their group. with check repeats the test so the owner
-- column cannot be handed to somebody else in the same update.
drop policy if exists "owner renames group" on public.groups;
create policy "owner renames group" on public.groups
  for update to authenticated
  using      (owner = auth.uid())
  with check (owner = auth.uid());

-- The owner of a group, and only the owner, may turn someone out of it. The
-- check reads groups.owner rather than group_members, so it does not recurse.

drop policy if exists "owner removes members" on public.group_members;
create policy "owner removes members" on public.group_members
  for delete to authenticated
  using (exists (
    select 1 from public.groups g
    where g.id = group_members.group_id and g.owner = auth.uid()
  ));

-- and may drop a guest somebody shared into their group
drop policy if exists "owner removes guests" on public.group_guests;
create policy "owner removes guests" on public.group_guests
  for delete to authenticated
  using (exists (
    select 1 from public.groups g
    where g.id = group_guests.group_id and g.owner = auth.uid()
  ));

-- deleting a group should take its memberships with it, whatever the existing
-- constraint happens to be called
do $$
declare fk text;
begin
  select c.conname into fk
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  where t.relname = 'group_members'
    and c.contype  = 'f'
    and c.confrelid = 'public.groups'::regclass
  limit 1;

  if fk is not null then
    execute format('alter table public.group_members drop constraint %I', fk);
  end if;

  alter table public.group_members
    add constraint group_members_group_id_fkey
    foreign key (group_id) references public.groups (id) on delete cascade;
end $$;

-- To see what ended up in place:
--   select tablename, policyname, cmd from pg_policies
--   where schemaname = 'public' order by tablename, policyname;
