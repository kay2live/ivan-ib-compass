-- Run once in Supabase Dashboard → SQL Editor.
create table if not exists public.user_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.user_data enable row level security;
drop policy if exists "Users can read own data" on public.user_data;
create policy "Users can read own data" on public.user_data for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can insert own data" on public.user_data;
create policy "Users can insert own data" on public.user_data for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update own data" on public.user_data;
create policy "Users can update own data" on public.user_data for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Users can delete own data" on public.user_data;
create policy "Users can delete own data" on public.user_data for delete to authenticated using ((select auth.uid()) = user_id);
grant select, insert, update, delete on public.user_data to authenticated;
