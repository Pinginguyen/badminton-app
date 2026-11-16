-- Club Squad schema for Supabase. Apply once to a new project.
-- No seed data is included. All monetary values are integer VND.
-- New accounts remain inactive until an admin approves them. Bootstrap the
-- first admin explicitly from the Supabase SQL editor.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  role text not null default 'member' check (role in ('admin', 'member')),
  skill_level smallint not null default 1 check (skill_level between 1 and 4),
  elo_rating integer not null default 1000 check (elo_rating >= 0),
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  court_count smallint not null default 1 check (court_count between 1 and 3),
  status text not null default 'scheduled'
    check (status in ('scheduled', 'live', 'completed', 'cancelled')),
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sessions_valid_time check (ends_at > starts_at)
);

create table public.attendance (
  session_id uuid not null references public.sessions (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'invited'
    check (status in ('invited', 'attending', 'absent', 'cancelled')),
  attendance_weight numeric(2, 1) not null default 1.0
    check (attendance_weight in (0.0, 0.5, 1.0)),
  checked_in_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (session_id, member_id)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions (id) on delete cascade,
  court_number smallint not null check (court_number between 1 and 3),
  round_number integer not null check (round_number > 0),
  team_a_player_1 uuid not null references public.profiles (id),
  team_a_player_2 uuid not null references public.profiles (id),
  team_b_player_1 uuid not null references public.profiles (id),
  team_b_player_2 uuid not null references public.profiles (id),
  team_a_score integer check (team_a_score >= 0),
  team_b_score integer check (team_b_score >= 0),
  status text not null default 'scheduled'
    check (status in ('scheduled', 'live', 'completed', 'cancelled')),
  is_admin_override boolean not null default false,
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint matches_distinct_players check (
    team_a_player_1 <> team_a_player_2
    and team_a_player_1 <> team_b_player_1
    and team_a_player_1 <> team_b_player_2
    and team_a_player_2 <> team_b_player_1
    and team_a_player_2 <> team_b_player_2
    and team_b_player_1 <> team_b_player_2
  ),
  constraint matches_unique_round_court unique (session_id, round_number, court_number)
);

create table public.bills (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions (id) on delete cascade,
  member_id uuid not null references public.profiles (id) on delete cascade,
  total_amount_vnd integer not null check (total_amount_vnd >= 0),
  shared_court_vnd integer not null default 0 check (shared_court_vnd >= 0),
  shuttle_vnd integer not null default 0 check (shuttle_vnd >= 0),
  extras_vnd integer not null default 0 check (extras_vnd >= 0),
  late_fee_vnd integer not null default 0 check (late_fee_vnd >= 0),
  absent_charge boolean not null default false,
  itemized_details jsonb not null default '{}'::jsonb,
  updated_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (session_id, member_id)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  member_id uuid not null,
  amount_vnd integer not null check (amount_vnd > 0),
  transfer_memo text generated always as (
    'CLB_' || session_id::text || '_' || member_id::text
  ) stored,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  bank_transaction_ref text,
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  constraint payments_bill_fk foreign key (session_id, member_id)
    references public.bills (session_id, member_id) on delete cascade,
  constraint payments_one_per_bill unique (session_id, member_id),
  constraint payments_approval_fields check (
    (status = 'approved' and approved_by is not null and approved_at is not null)
    or (status <> 'approved' and approved_by is null and approved_at is null)
  )
);

-- This contains the recipient details required by members to render VietQR.
-- Do not put banking credentials or secrets here.
create table public.payment_settings (
  singleton boolean primary key default true check (singleton),
  bank_bin text not null check (bank_bin ~ '^[0-9]{6}$'),
  account_number text not null check (account_number ~ '^[A-Za-z0-9]{6,32}$'),
  account_name text not null,
  updated_by uuid references public.profiles (id),
  updated_at timestamptz not null default now()
);

create or replace function public.is_active_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.is_active
  );
$$;

create or replace function public.is_club_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.is_active
      and p.role = 'admin'
  );
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, is_active)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.protect_member_managed_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not public.is_club_admin() then
    if new.role is distinct from old.role
      or new.skill_level is distinct from old.skill_level
      or new.elo_rating is distinct from old.elo_rating
      or new.is_active is distinct from old.is_active then
      raise exception 'Only an admin can change role, rating, or membership status'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.protect_attendance_weight()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and not public.is_club_admin() then
    if (tg_op = 'INSERT' and new.attendance_weight is distinct from 1.0)
      or (tg_op = 'UPDATE' and new.attendance_weight is distinct from old.attendance_weight) then
      raise exception 'Only an admin can change attendance weight'
        using errcode = '42501';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.validate_payment_submission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  expected_amount integer;
begin
  select b.total_amount_vnd
    into expected_amount
    from public.bills b
    where b.session_id = new.session_id
      and b.member_id = new.member_id;

  if expected_amount is null or new.amount_vnd <> expected_amount then
    raise exception 'Payment amount must exactly match the member bill'
      using errcode = '23514';
  end if;

  if tg_op = 'INSERT' then
    if not public.is_club_admin() and (
      new.member_id is distinct from (select auth.uid())
      or new.status <> 'pending'
      or new.approved_by is not null
      or new.approved_at is not null
    ) then
      raise exception 'Members may submit only their own pending payment'
        using errcode = '42501';
    end if;
  elsif not public.is_club_admin() then
    raise exception 'Only an admin can update payment status'
      using errcode = '42501';
  end if;

  if new.status = 'approved' then
    new.approved_by := coalesce(new.approved_by, (select auth.uid()));
    new.approved_at := coalesce(new.approved_at, now());
  else
    new.approved_by := null;
    new.approved_at := null;
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

create trigger profiles_protect_fields
  before update on public.profiles
  for each row execute function public.protect_member_managed_fields();

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger sessions_set_updated_at
  before update on public.sessions
  for each row execute function public.set_updated_at();

create trigger attendance_protect_weight
  before insert or update on public.attendance
  for each row execute function public.protect_attendance_weight();

create trigger matches_set_updated_at
  before update on public.matches
  for each row execute function public.set_updated_at();

create trigger bills_set_updated_at
  before update on public.bills
  for each row execute function public.set_updated_at();

create trigger payments_validate
  before insert or update on public.payments
  for each row execute function public.validate_payment_submission();

alter table public.profiles enable row level security;
alter table public.sessions enable row level security;
alter table public.attendance enable row level security;
alter table public.matches enable row level security;
alter table public.bills enable row level security;
alter table public.payments enable row level security;
alter table public.payment_settings enable row level security;

create policy "Members can read the active roster"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_active_member()));
create policy "Members can update their own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
create policy "Admins can manage profiles"
  on public.profiles for all to authenticated
  using ((select public.is_club_admin()))
  with check ((select public.is_club_admin()));

create policy "Active members can read sessions"
  on public.sessions for select to authenticated
  using ((select public.is_active_member()));
create policy "Admins can manage sessions"
  on public.sessions for all to authenticated
  using ((select public.is_club_admin()))
  with check ((select public.is_club_admin()));

create policy "Active members can read attendance"
  on public.attendance for select to authenticated
  using ((select public.is_active_member()));
create policy "Members can add their own attendance"
  on public.attendance for insert to authenticated
  with check (
    member_id = (select auth.uid())
    and (select public.is_active_member())
  );
create policy "Members can update their own attendance"
  on public.attendance for update to authenticated
  using (member_id = (select auth.uid()))
  with check (member_id = (select auth.uid()));
create policy "Admins can manage attendance"
  on public.attendance for all to authenticated
  using ((select public.is_club_admin()))
  with check ((select public.is_club_admin()));

create policy "Active members can read matches"
  on public.matches for select to authenticated
  using ((select public.is_active_member()));
create policy "Admins can manage matches"
  on public.matches for all to authenticated
  using ((select public.is_club_admin()))
  with check ((select public.is_club_admin()));

create policy "Members can read their own bills"
  on public.bills for select to authenticated
  using (
    member_id = (select auth.uid())
    or (select public.is_club_admin())
  );
create policy "Admins can manage bills"
  on public.bills for all to authenticated
  using ((select public.is_club_admin()))
  with check ((select public.is_club_admin()));

create policy "Members can read their own payments"
  on public.payments for select to authenticated
  using (
    member_id = (select auth.uid())
    or (select public.is_club_admin())
  );
create policy "Members can submit their own payment"
  on public.payments for insert to authenticated
  with check (
    member_id = (select auth.uid())
    and status = 'pending'
    and (select public.is_active_member())
  );
create policy "Admins can manage payments"
  on public.payments for all to authenticated
  using ((select public.is_club_admin()))
  with check ((select public.is_club_admin()));

create policy "Active members can read payment settings"
  on public.payment_settings for select to authenticated
  using ((select public.is_active_member()));
create policy "Admins can manage payment settings"
  on public.payment_settings for all to authenticated
  using ((select public.is_club_admin()))
  with check ((select public.is_club_admin()));

grant usage on schema public to authenticated;
grant select on public.profiles, public.sessions, public.attendance,
  public.matches, public.bills, public.payments, public.payment_settings
  to authenticated;
grant update (display_name, avatar_url, role, skill_level, elo_rating, is_active)
  on public.profiles to authenticated;
grant insert, update on public.sessions to authenticated;
grant insert, update on public.attendance to authenticated;
grant insert, update on public.matches to authenticated;
grant insert, update on public.bills to authenticated;
grant insert, update on public.payments to authenticated;
grant insert, update on public.payment_settings to authenticated;
grant execute on function public.is_active_member() to authenticated;
grant execute on function public.is_club_admin() to authenticated;

