-- Run once in Supabase Dashboard → SQL Editor after supabase-schema.sql.
-- Adds one shared family workspace per account with Owner/Student roles.

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  invite_code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'student')),
  joined_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table if not exists public.workspace_data (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.workspace_data enable row level security;

create or replace function public.is_workspace_member(target_workspace uuid)
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members
    where workspace_id = target_workspace and user_id = auth.uid()
  );
$$;

create or replace function public.is_workspace_owner(target_workspace uuid)
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members
    where workspace_id = target_workspace and user_id = auth.uid() and role = 'owner'
  );
$$;

drop policy if exists "Members can view workspace" on public.workspaces;
create policy "Members can view workspace" on public.workspaces
for select to authenticated using (public.is_workspace_member(id));

drop policy if exists "Owners can update workspace" on public.workspaces;
create policy "Owners can update workspace" on public.workspaces
for update to authenticated using (public.is_workspace_owner(id))
with check (public.is_workspace_owner(id));

drop policy if exists "Members can view members" on public.workspace_members;
create policy "Members can view members" on public.workspace_members
for select to authenticated using (public.is_workspace_member(workspace_id));

drop policy if exists "Members can view shared data" on public.workspace_data;
create policy "Members can view shared data" on public.workspace_data
for select to authenticated using (public.is_workspace_member(workspace_id));

drop policy if exists "Members can insert shared data" on public.workspace_data;
create policy "Members can insert shared data" on public.workspace_data
for insert to authenticated with check (public.is_workspace_member(workspace_id));

drop policy if exists "Members can update shared data" on public.workspace_data;
create policy "Members can update shared data" on public.workspace_data
for update to authenticated using (public.is_workspace_member(workspace_id))
with check (public.is_workspace_member(workspace_id));

create or replace function public.create_family_workspace(workspace_name text)
returns table (workspace_id uuid, invite_code text)
language plpgsql security definer set search_path = public
as $$
declare
  new_workspace_id uuid;
  new_invite_code text;
  existing_payload jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if exists (select 1 from public.workspace_members where user_id = auth.uid()) then
    raise exception 'This account already belongs to a workspace';
  end if;
  new_invite_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.workspaces(name, invite_code, created_by)
  values (trim(workspace_name), new_invite_code, auth.uid()) returning id into new_workspace_id;
  insert into public.workspace_members(workspace_id, user_id, role)
  values (new_workspace_id, auth.uid(), 'owner');
  select payload into existing_payload from public.user_data where user_id = auth.uid();
  insert into public.workspace_data(workspace_id, payload)
  values (new_workspace_id, coalesce(existing_payload, '{}'::jsonb));
  return query select new_workspace_id, new_invite_code;
end;
$$;

create or replace function public.join_family_workspace(code text)
returns uuid language plpgsql security definer set search_path = public
as $$
declare target_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if exists (select 1 from public.workspace_members where user_id = auth.uid()) then
    raise exception 'This account already belongs to a workspace';
  end if;
  select id into target_id from public.workspaces where invite_code = upper(trim(code));
  if target_id is null then raise exception 'Invalid invitation code'; end if;
  insert into public.workspace_members(workspace_id, user_id, role)
  values (target_id, auth.uid(), 'student');
  return target_id;
end;
$$;

create or replace function public.get_my_workspace()
returns table (workspace_id uuid, workspace_name text, invite_code text, member_role text)
language sql stable security definer set search_path = public
as $$
  select w.id, w.name, case when m.role = 'owner' then w.invite_code else null end, m.role
  from public.workspace_members m join public.workspaces w on w.id = m.workspace_id
  where m.user_id = auth.uid()
  limit 1;
$$;

create or replace function public.rotate_workspace_invite(target_workspace uuid)
returns text language plpgsql security definer set search_path = public
as $$
declare new_code text;
begin
  if not public.is_workspace_owner(target_workspace) then raise exception 'Owner access required'; end if;
  new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  update public.workspaces set invite_code = new_code where id = target_workspace;
  return new_code;
end;
$$;

grant execute on function public.create_family_workspace(text) to authenticated;
grant execute on function public.join_family_workspace(text) to authenticated;
grant execute on function public.get_my_workspace() to authenticated;
grant execute on function public.rotate_workspace_invite(uuid) to authenticated;
grant select, update on public.workspaces to authenticated;
grant select on public.workspace_members to authenticated;
grant select, insert, update on public.workspace_data to authenticated;
