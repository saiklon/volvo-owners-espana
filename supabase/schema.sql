create extension if not exists pgcrypto;
do $$ begin create type public.member_role as enum ('member','admin'); exception when duplicate_object then null; end $$;
do $$ begin create type public.vehicle_status as enum ('pending','approved','rejected'); exception when duplicate_object then null; end $$;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null, email text not null, province text not null, town text not null,
 phone text, role public.member_role not null default 'member', created_at timestamptz not null default now()
);
create table if not exists public.vehicles (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade,
 model text not null, year integer not null check(year between 1927 and 2027),
 engine text, trim text, description text, photo_path text not null,
 verification_status public.vehicle_status not null default 'pending',
 reviewed_at timestamptz, reviewed_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;
drop policy if exists "profile read own or admin" on public.profiles;
create policy "profile read own or admin" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
drop policy if exists "profile insert own" on public.profiles;
create policy "profile insert own" on public.profiles for insert to authenticated with check(id=auth.uid() and role='member');
drop policy if exists "vehicle read own or admin" on public.vehicles;
create policy "vehicle read own or admin" on public.vehicles for select to authenticated using(owner_id=auth.uid() or public.is_admin());
drop policy if exists "vehicle insert own" on public.vehicles;
create policy "vehicle insert own" on public.vehicles for insert to authenticated with check(owner_id=auth.uid() and verification_status='pending');
drop policy if exists "vehicle update admin only" on public.vehicles;
create policy "vehicle update admin only" on public.vehicles for update to authenticated using(public.is_admin()) with check(public.is_admin());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('vehicle-evidence','vehicle-evidence',false,8388608,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "upload own vehicle evidence" on storage.objects;
create policy "upload own vehicle evidence" on storage.objects for insert to authenticated with check(bucket_id='vehicle-evidence' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "read own or admin evidence" on storage.objects;
create policy "read own or admin evidence" on storage.objects for select to authenticated using(bucket_id='vehicle-evidence' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin()));
-- Tras crear la cuenta del administrador y su perfil, asignar el rol:
-- update public.profiles set role='admin' where email='TU_CORREO';
