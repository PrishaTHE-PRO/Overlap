-- Everyone you add from a screenshot, stored against your own account.
--
-- This is deliberately separate from `schedules`. `schedules` holds the one
-- schedule you share with a group, so group members can read it. A roster is
-- private: the policy below lets you read and write only your own row, so the
-- friends you add stay yours and simply follow you between devices.
--
-- Run once in the Supabase dashboard: SQL Editor -> New query -> Run.

create table if not exists public.rosters (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  people     jsonb       not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.rosters enable row level security;

drop policy if exists "own roster only" on public.rosters;
create policy "own roster only" on public.rosters
  for all
  to authenticated
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);
