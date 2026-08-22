-- Someone you added from a screenshot, shared into one of your groups.
--
-- These people have no account, so they can never be rows in group_members.
-- A copy of the schedule lives here instead: readable by everyone in that one
-- group, writable only by whoever added them. Sharing is per person, so the
-- rest of your roster stays private (see rosters.sql).
--
-- Run once in the Supabase dashboard: SQL Editor -> New query -> Run.

create table if not exists public.group_guests (
  group_id   uuid        not null references public.groups (id) on delete cascade,
  added_by   uuid        not null references auth.users (id)    on delete cascade,
  person_id  text        not null,
  person     jsonb       not null,
  updated_at timestamptz not null default now(),
  primary key (group_id, added_by, person_id)
);

alter table public.group_guests enable row level security;

-- anyone in the group may read the people shared into it
drop policy if exists "group can read guests" on public.group_guests;
create policy "group can read guests" on public.group_guests
  for select to authenticated
  using (exists (
    select 1 from public.group_members gm
    where gm.group_id = group_guests.group_id and gm.user_id = auth.uid()
  ));

-- only the person who added them may change or withdraw them,
-- and only into a group they are actually in
drop policy if exists "adder manages guests" on public.group_guests;
create policy "adder manages guests" on public.group_guests
  for all to authenticated
  using (added_by = auth.uid())
  with check (added_by = auth.uid() and exists (
    select 1 from public.group_members gm
    where gm.group_id = group_guests.group_id and gm.user_id = auth.uid()
  ));
