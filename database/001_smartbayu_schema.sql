-- ============================================================
-- SmartBayu Database Schema — Full Migration
-- Run in Supabase SQL Editor (requires pgvector extension)
-- ============================================================

-- 0. Enable pgvector for face embeddings
create extension if not exists vector with schema extensions;

-- ============================================================
-- 1. STAFF TABLE
-- ============================================================
create table if not exists public.staff (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete set null,
  company_id   uuid not null,
  full_name    text not null,
  email        text,
  phone        text,
  ic_number    text,
  staff_number text,
  position     text,
  department   text default 'General',
  app_role     text not null default 'staff' check (app_role in ('staff','hr','admin','manager')),
  employment_type text default 'Full-time',
  is_active    boolean default true,
  date_joined  date,
  photo_url    text,
  profile_photo_url text,
  note         text,
  site         text,
  -- Face verification
  face_embedding  double precision[],
  face_image_url  text,
  -- Live status (updated on punch)
  last_in      timestamptz,
  last_out     timestamptz,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

create unique index if not exists idx_staff_user_id on public.staff(user_id) where user_id is not null;
create index if not exists idx_staff_company on public.staff(company_id);
create index if not exists idx_staff_email on public.staff(email);

-- ============================================================
-- 2. ATTENDANCE TABLE
-- ============================================================
create table if not exists public.attendance (
  id              uuid primary key default gen_random_uuid(),
  staff_id        uuid not null references public.staff(id) on delete cascade,
  company_id      uuid not null,
  attendance_date date not null,
  status          text default 'absent' check (status in ('present','late','absent','leave','holiday')),
  punches         jsonb default '[]'::jsonb,
  check_in_time   timestamptz,
  check_out_time  timestamptz,
  clock_in_lat    double precision,
  clock_in_lng    double precision,
  clock_out_lat   double precision,
  clock_out_lng   double precision,
  face_verified   boolean default false,
  device_id       text,
  hours_worked    double precision default 0,
  overtime_hours  double precision default 0,
  source          text default 'mobile' check (source in ('mobile','manual','system')),
  hr_override     boolean default false,
  hr_notes        text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now(),

  constraint uq_staff_date unique (staff_id, attendance_date)
);

create index if not exists idx_attendance_company_date on public.attendance(company_id, attendance_date);
create index if not exists idx_attendance_staff on public.attendance(staff_id, attendance_date desc);

-- ============================================================
-- 3. LEAVE RECORDS TABLE
-- ============================================================
create table if not exists public.leave_records (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references public.staff(id) on delete cascade,
  company_id  uuid not null,
  leave_type  text not null check (leave_type in ('Annual','Sick','Emergency','Unpaid','Maternity','Paternity','Replacement','Compassionate')),
  start_date  date not null,
  end_date    date not null,
  days        numeric(5,1) not null default 1,
  reason      text,
  status      text default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  hr_notes    text,
  approved_by uuid references public.staff(id),
  approved_at timestamptz,
  created_at  timestamptz default now()
);

create index if not exists idx_leave_staff on public.leave_records(staff_id, status);
create index if not exists idx_leave_company on public.leave_records(company_id);

-- ============================================================
-- 4. LEAVE BALANCES TABLE
-- ============================================================
create table if not exists public.leave_balances (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references public.staff(id) on delete cascade,
  company_id  uuid not null,
  year        int not null default extract(year from current_date),
  annual      numeric(5,1) default 14,
  sick        numeric(5,1) default 14,
  emergency   numeric(5,1) default 3,
  maternity   numeric(5,1) default 60,
  paternity   numeric(5,1) default 7,
  replacement numeric(5,1) default 0,
  compassionate numeric(5,1) default 3,
  created_at  timestamptz default now(),

  constraint uq_leave_balance unique (staff_id, year)
);

-- ============================================================
-- 5. STAFF CLAIMS TABLE
-- ============================================================
create table if not exists public.staff_claims (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references public.staff(id) on delete cascade,
  company_id  uuid not null,
  claim_type  text not null check (claim_type in ('Meal','Transport','Tools','Accommodation','Medical','Others')),
  claim_date  date not null,
  amount      numeric(12,2) not null default 0,
  description text,
  receipt_url text,
  status      text default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  hr_notes    text,
  approved_by uuid references public.staff(id),
  approved_at timestamptz,
  created_at  timestamptz default now()
);

create index if not exists idx_claims_staff on public.staff_claims(staff_id, status);
create index if not exists idx_claims_company on public.staff_claims(company_id);

-- ============================================================
-- 6. PAYSLIPS TABLE
-- ============================================================
create table if not exists public.payslips (
  id               uuid primary key default gen_random_uuid(),
  staff_id         uuid not null references public.staff(id) on delete cascade,
  company_id       uuid not null,
  month_label      text not null,
  period_start     date,
  period_end       date,
  basic_salary     numeric(12,2) default 0,
  total_allowances numeric(12,2) default 0,
  allowances       jsonb default '{}'::jsonb,
  total_deductions numeric(12,2) default 0,
  deductions       jsonb default '{}'::jsonb,
  epf_employee     numeric(12,2) default 0,
  epf_employer     numeric(12,2) default 0,
  socso_employee   numeric(12,2) default 0,
  socso_employer   numeric(12,2) default 0,
  eis_employee     numeric(12,2) default 0,
  gross_pay        numeric(12,2) default 0,
  net_pay          numeric(12,2) default 0,
  pdf_url          text,
  mypms_journal_id uuid,
  status           text default 'draft' check (status in ('draft','approved','paid')),
  created_at       timestamptz default now()
);

create index if not exists idx_payslips_staff on public.payslips(staff_id);
create index if not exists idx_payslips_company on public.payslips(company_id);

-- ============================================================
-- 7. STAFF NOTIFICATIONS TABLE
-- ============================================================
create table if not exists public.staff_notifications (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references public.staff(id) on delete cascade,
  company_id uuid,
  title      text not null,
  message    text,
  type       text default 'general',
  data       jsonb default '{}'::jsonb,
  is_read    boolean default false,
  created_at timestamptz default now()
);

create index if not exists idx_notif_staff on public.staff_notifications(staff_id, is_read, created_at desc);

-- ============================================================
-- 8. GEOFENCES TABLE
-- ============================================================
create table if not exists public.staff_geofences (
  id       uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  name     text not null,
  lat      double precision not null,
  lng      double precision not null,
  radius_meters int not null default 3000,
  active   boolean default true,
  created_at timestamptz default now()
);

-- ============================================================
-- TRIGGERS: auto-update updated_at
-- ============================================================
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_staff_updated on public.staff;
create trigger trg_staff_updated
  before update on public.staff
  for each row execute function public.set_updated_at();

drop trigger if exists trg_attendance_updated on public.attendance;
create trigger trg_attendance_updated
  before update on public.attendance
  for each row execute function public.set_updated_at();

-- ============================================================
-- TRIGGER: auto-deduct leave balance on approval
-- ============================================================
create or replace function public.deduct_leave_balance()
returns trigger as $$
begin
  if new.status = 'approved' and (old.status is null or old.status != 'approved') then
    -- Ensure balance row exists for this year
    insert into public.leave_balances (staff_id, company_id, year)
    values (new.staff_id, new.company_id, extract(year from new.start_date)::int)
    on conflict (staff_id, year) do nothing;

    -- Deduct based on leave type
    case lower(new.leave_type)
      when 'annual' then
        update public.leave_balances set annual = annual - new.days
        where staff_id = new.staff_id and year = extract(year from new.start_date)::int;
      when 'sick' then
        update public.leave_balances set sick = sick - new.days
        where staff_id = new.staff_id and year = extract(year from new.start_date)::int;
      when 'emergency' then
        update public.leave_balances set emergency = emergency - new.days
        where staff_id = new.staff_id and year = extract(year from new.start_date)::int;
      when 'maternity' then
        update public.leave_balances set maternity = maternity - new.days
        where staff_id = new.staff_id and year = extract(year from new.start_date)::int;
      when 'paternity' then
        update public.leave_balances set paternity = paternity - new.days
        where staff_id = new.staff_id and year = extract(year from new.start_date)::int;
      when 'replacement' then
        update public.leave_balances set replacement = replacement - new.days
        where staff_id = new.staff_id and year = extract(year from new.start_date)::int;
      when 'compassionate' then
        update public.leave_balances set compassionate = compassionate - new.days
        where staff_id = new.staff_id and year = extract(year from new.start_date)::int;
      else null;
    end case;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_leave_balance_deduct on public.leave_records;
create trigger trg_leave_balance_deduct
  after insert or update on public.leave_records
  for each row execute function public.deduct_leave_balance();

-- ============================================================
-- RLS POLICIES
-- ============================================================
alter table public.staff enable row level security;
alter table public.attendance enable row level security;
alter table public.leave_records enable row level security;
alter table public.leave_balances enable row level security;
alter table public.staff_claims enable row level security;
alter table public.payslips enable row level security;
alter table public.staff_notifications enable row level security;
alter table public.staff_geofences enable row level security;

-- Helper: get current user's staff record
create or replace function public.get_my_staff_id()
returns uuid as $$
  select id from public.staff where user_id = auth.uid() limit 1;
$$ language sql stable security definer;

create or replace function public.get_my_company_id()
returns uuid as $$
  select company_id from public.staff where user_id = auth.uid() limit 1;
$$ language sql stable security definer;

create or replace function public.is_hr_user()
returns boolean as $$
  select exists(
    select 1 from public.staff
    where user_id = auth.uid()
    and app_role in ('hr','admin','manager')
  );
$$ language sql stable security definer;

-- STAFF: own row always, HR sees company
create policy "staff_select_own" on public.staff for select using (user_id = auth.uid());
create policy "staff_select_hr" on public.staff for select using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "staff_update_own" on public.staff for update using (user_id = auth.uid());
create policy "staff_update_hr" on public.staff for update using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "staff_insert_hr" on public.staff for insert with check (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "staff_delete_hr" on public.staff for delete using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);

-- ATTENDANCE: own rows always, HR sees company
create policy "att_select_own" on public.attendance for select using (staff_id = public.get_my_staff_id());
create policy "att_select_hr" on public.attendance for select using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "att_insert_own" on public.attendance for insert with check (staff_id = public.get_my_staff_id());
create policy "att_update_own" on public.attendance for update using (staff_id = public.get_my_staff_id());
create policy "att_update_hr" on public.attendance for update using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);

-- LEAVE RECORDS: own rows, HR sees company
create policy "leave_select_own" on public.leave_records for select using (staff_id = public.get_my_staff_id());
create policy "leave_select_hr" on public.leave_records for select using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "leave_insert_own" on public.leave_records for insert with check (staff_id = public.get_my_staff_id());
create policy "leave_update_hr" on public.leave_records for update using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);

-- LEAVE BALANCES: own rows, HR sees company
create policy "lb_select_own" on public.leave_balances for select using (staff_id = public.get_my_staff_id());
create policy "lb_select_hr" on public.leave_balances for select using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "lb_insert_hr" on public.leave_balances for insert with check (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "lb_update_hr" on public.leave_balances for update using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);

-- CLAIMS: own rows, HR sees company
create policy "claims_select_own" on public.staff_claims for select using (staff_id = public.get_my_staff_id());
create policy "claims_select_hr" on public.staff_claims for select using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "claims_insert_own" on public.staff_claims for insert with check (staff_id = public.get_my_staff_id());
create policy "claims_update_hr" on public.staff_claims for update using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);

-- PAYSLIPS: own rows, HR sees company
create policy "pay_select_own" on public.payslips for select using (staff_id = public.get_my_staff_id());
create policy "pay_select_hr" on public.payslips for select using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "pay_insert_hr" on public.payslips for insert with check (
  company_id = public.get_my_company_id() and public.is_hr_user()
);

-- NOTIFICATIONS: own rows only
create policy "notif_select_own" on public.staff_notifications for select using (staff_id = public.get_my_staff_id());
create policy "notif_insert_any" on public.staff_notifications for insert with check (true);
create policy "notif_update_own" on public.staff_notifications for update using (staff_id = public.get_my_staff_id());

-- GEOFENCES: read by anyone in company, write by HR
create policy "geo_select" on public.staff_geofences for select using (
  company_id = public.get_my_company_id()
);
create policy "geo_insert_hr" on public.staff_geofences for insert with check (
  company_id = public.get_my_company_id() and public.is_hr_user()
);
create policy "geo_update_hr" on public.staff_geofences for update using (
  company_id = public.get_my_company_id() and public.is_hr_user()
);

-- ============================================================
-- STORAGE BUCKET
-- ============================================================
-- Run this separately if bucket doesn't exist:
-- insert into storage.buckets (id, name, public) values ('smartbayu', 'smartbayu', true);
