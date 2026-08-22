-- Seeing who else is in your groups.
--
-- The filters name a group, so the app has to know which group each synced
-- person came from. It reads that from group_members. If the only rows you are
-- allowed to read are your own, everyone else arrives with no group attached
-- and every filter but Everyone looks empty.
--
-- The check has to go through a security definer function. A policy on
-- group_members that queries group_members directly recurses and Postgres
-- rejects it at query time.
--
-- Run once in the Supabase dashboard: SQL Editor -> New query -> Run.

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
