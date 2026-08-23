-- What can a signed-in stranger actually read?
--
-- The app trusts row level security completely: pull() asks for every row of
-- schedules and lets the database decide which come back. So the answer to
-- "can someone outside my groups read my timetable" is entirely in these
-- policies, and nothing in the page can be read to find out.
--
-- Run in the Supabase SQL editor and read the output against the notes below.

-- 1. Every policy, and the condition it actually applies.
select tablename,
       policyname,
       cmd,
       roles,
       qual        as using_condition,
       with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;

-- What to look for, table by table:
--
--   schedules   SELECT must be limited to people who share a group with you.
--               A using_condition of `true`, or one that only checks
--               `auth.role() = 'authenticated'`, means every signed-in account
--               on the internet can read every timetable in the database.
--               This is the one that matters most.
--
--   profiles    Same question for names. `true` leaks every display name.
--
--   rosters     Must be `auth.uid() = user_id` and nothing else. This row
--               holds the schedules of friends who never signed up.
--
--   group_guests  SELECT should require membership of that group.
--
--   groups      Check whether UPDATE exists at all. Without a policy the
--               update is refused, which is what you want; a permissive one
--               would let any member rename a group or change its code.

-- 2. Any table with RLS switched off entirely. This should return no rows.
select c.relname as table_without_rls
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

-- 3. How join codes are generated. If the default is short or sequential,
--    codes can be guessed, and a guessed code is a way into a group.
select column_name, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'groups' and column_name = 'join_code';

-- 4. What the join RPC does, and whether it runs as its owner.
select p.proname,
       p.prosecdef as security_definer,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('join_group', 'is_group_member');
