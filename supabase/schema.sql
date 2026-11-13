-- Volvo Owners España · Supabase schema v2
-- Ejecutar en Supabase > SQL Editor. Nunca publicar service_role.
create extension if not exists pgcrypto;
do $$ begin create type public.member_role as enum ('member','admin'); exception when duplicate_object then null; end $$;
do $$ begin create type public.vehicle_status as enum ('pending','approved','rejected'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null,
 display_name text not null,
 email text not null,
 province text not null,
 town text not null,
 phone text,
 role public.member_role not null default 'member',
 membership_status text not null default 'pending' check(membership_status in ('pending','approved')),
 created_at timestamptz not null default now()
);
alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists membership_status text not null default 'pending';
update public.profiles set display_name=coalesce(nullif(display_name,''),full_name) where display_name is null or display_name='';
alter table public.profiles alter column display_name set not null;

create table if not exists public.vehicles (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 owner_display_name text not null,
 model text not null,
 year integer not null check(year between 1927 and 2027),
 engine text,
 trim text,
 story text not null check(char_length(story) between 30 and 1200),
 photo_path text not null,
 verification_status public.vehicle_status not null default 'pending',
 reviewed_at timestamptz,
 reviewed_by uuid references public.profiles(id),
 created_at timestamptz not null default now()
);
alter table public.vehicles add column if not exists owner_display_name text;
alter table public.vehicles add column if not exists story text;
update public.vehicles v set owner_display_name=coalesce(nullif(v.owner_display_name,''),p.display_name,p.full_name) from public.profiles p where p.id=v.owner_id and (v.owner_display_name is null or v.owner_display_name='');
update public.vehicles set story='Historia pendiente de completar.' where story is null or char_length(story)<30;
alter table public.vehicles alter column owner_display_name set not null;
alter table public.vehicles alter column story set not null;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare meta jsonb;
begin
 meta:=coalesce(new.raw_user_meta_data,'{}'::jsonb);
 insert into public.profiles(id,full_name,display_name,email,province,town,phone)
 values(new.id,
  coalesce(nullif(meta->>'full_name',''),split_part(new.email,'@',1)),
  coalesce(nullif(meta->>'display_name',''),nullif(meta->>'full_name',''),split_part(new.email,'@',1)),
  new.email,
  coalesce(nullif(meta->>'province',''),'Pendiente'),
  coalesce(nullif(meta->>'town',''),'Pendiente'),
  nullif(meta->>'phone',''))
 on conflict(id) do update set email=excluded.email;
 return new;
end $$;
drop trigger if exists on_auth_user_created_voe on auth.users;
create trigger on_auth_user_created_voe after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
revoke all on public.profiles from anon,authenticated;
revoke all on public.vehicles from anon,authenticated;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,update on public.vehicles to authenticated;

drop policy if exists "profile read own or admin" on public.profiles;
drop policy if exists "profile insert own" on public.profiles;
drop policy if exists "profile update own" on public.profiles;
drop policy if exists "profile update admin only" on public.profiles;
create policy "profile read own or admin" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy "profile insert own" on public.profiles for insert to authenticated with check(id=auth.uid() and role='member' and membership_status='pending');
create policy "profile update admin only" on public.profiles for update to authenticated using(public.is_admin()) with check(public.is_admin());

drop policy if exists "vehicle read own or admin" on public.vehicles;
drop policy if exists "vehicle insert own" on public.vehicles;
drop policy if exists "vehicle update admin only" on public.vehicles;
create policy "vehicle read own or admin or verified club member" on public.vehicles for select to authenticated using(
 owner_id=auth.uid() or public.is_admin() or
 (verification_status='approved' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.membership_status='approved'))
);
create policy "vehicle insert own" on public.vehicles for insert to authenticated with check(owner_id=auth.uid() and verification_status='pending' and reviewed_at is null and reviewed_by is null);
create policy "vehicle update admin only" on public.vehicles for update to authenticated using(public.is_admin()) with check(public.is_admin());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('vehicle-photos','vehicle-photos',false,8388608,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "upload own vehicle photo" on storage.objects;
drop policy if exists "read own or admin vehicle photo" on storage.objects;
drop policy if exists "approved club members view approved photos" on storage.objects;
create policy "upload own vehicle photo" on storage.objects for insert to authenticated with check(bucket_id='vehicle-photos' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "read own or admin vehicle photo" on storage.objects for select to authenticated using(bucket_id='vehicle-photos' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin()));
create policy "approved club members view approved photos" on storage.objects for select to authenticated using(bucket_id='vehicle-photos' and exists(
 select 1 from public.vehicles v
 join public.profiles viewer on viewer.id=auth.uid()
 where v.photo_path=name and v.verification_status='approved' and viewer.membership_status='approved'
));

-- Tras crear la cuenta que administrará el club, asignarle permisos una sola vez:
-- update public.profiles set role='admin', membership_status='approved' where email='TU_CORREO_DE_ADMIN';
