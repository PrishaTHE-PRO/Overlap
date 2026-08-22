-- Leaving and deleting groups.
--
-- Postgres denies a delete that no policy allows, and PostgREST reports that
-- as a successful request that removed nothing. Without these two policies the
-- Leave button appears to do nothing at all, which is exactly how it behaved.
--
-- Run once in the Supabase dashboard: SQL Editor -> New query -> Run.

-- anyone may drop their own membership
drop policy if exists "leave a group" on public.group_members;
create policy "leave a group" on public.group_members
  for delete to authenticated
  using (user_id = auth.uid());

-- the owner may delete the whole group
drop policy if exists "owner deletes group" on public.groups;
create policy "owner deletes group" on public.groups
  for delete to authenticated
  using (owner = auth.uid());

-- so deleting a group takes its memberships with it rather than orphaning them
alter table public.group_members
  drop constraint if exists group_members_group_id_fkey;
alter table public.group_members
  add  constraint group_members_group_id_fkey
  foreign key (group_id) references public.groups (id) on delete cascade;
