-- شغّل الملف كله مرة واحدة في Supabase: SQL Editor > New query > Run
create extension if not exists pgcrypto;

create table if not exists services(
  id uuid primary key default gen_random_uuid(), title text not null, description text,
  sort_order int default 0, published boolean default true, created_at timestamptz default now());
create table if not exists contact_requests(
  id uuid primary key default gen_random_uuid(), name text not null, phone text not null,
  service text, message text, status text default 'جديد', created_at timestamptz default now());
create table if not exists clients(
  id uuid primary key default gen_random_uuid(), name text not null, phone text, email text,
  notes text, created_at timestamptz default now());
create table if not exists cases(
  id uuid primary key default gen_random_uuid(), case_number text, title text not null,
  type text, client_id uuid references clients(id) on delete set null, court text,
  status text default 'جارية', fee_agreed numeric default 0, opened_on date, notes text,
  created_at timestamptz default now());
create table if not exists court_sessions(
  id uuid primary key default gen_random_uuid(), case_id uuid references cases(id) on delete cascade,
  session_date date not null, notes text, created_at timestamptz default now());
create table if not exists payments(
  id uuid primary key default gen_random_uuid(), client_id uuid references clients(id) on delete set null,
  case_id uuid references cases(id) on delete set null, amount numeric not null, paid_on date default current_date,
  note text, created_at timestamptz default now());
create table if not exists expenses(
  id uuid primary key default gen_random_uuid(), case_id uuid references cases(id) on delete set null,
  category text, amount numeric not null, spent_on date default current_date, note text,
  created_at timestamptz default now());
create table if not exists files(
  id uuid primary key default gen_random_uuid(), case_id uuid references cases(id) on delete cascade,
  name text, path text, created_at timestamptz default now());

create table if not exists inventory_items(
  id uuid primary key default gen_random_uuid(), name text not null, category text,
  quantity numeric default 0, min_quantity numeric default 0, unit text, location text, note text,
  created_at timestamptz default now());
create table if not exists custody(
  id uuid primary key default gen_random_uuid(), holder text not null, kind text default 'نقدية',
  description text, amount numeric default 0, spent numeric default 0, status text default 'مع المستلم',
  received_on date default current_date, note text, created_at timestamptz default now());
create table if not exists powers_of_attorney(
  id uuid primary key default gen_random_uuid(), client_id uuid references clients(id) on delete set null,
  case_id uuid references cases(id) on delete set null, poa_number text, poa_type text, notary text,
  issued_on date, expires_on date, status text default 'ساري', path text, note text,
  created_at timestamptz default now());

-- الأمان: أي مستخدم مسجّل دخول (المحامي فقط) يتحكم في كل شيء
do $$ declare t text; begin
  foreach t in array array['services','contact_requests','clients','cases','court_sessions','payments','expenses','files','inventory_items','custody','powers_of_attorney'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists admin_all on %I', t);
    execute format('create policy admin_all on %I for all to authenticated using (true) with check (true)', t);
  end loop; end $$;

-- الزائر: يشوف الخدمات المنشورة ويبعت طلب تواصل فقط
drop policy if exists public_read_services on services;
create policy public_read_services on services for select to anon using (published = true);
drop policy if exists public_send_request on contact_requests;
create policy public_send_request on contact_requests for insert to anon with check (true);

-- مخزن الملفات (خاص)
insert into storage.buckets(id,name,public) values('files','files',false) on conflict do nothing;
drop policy if exists admin_files on storage.objects;
create policy admin_files on storage.objects for all to authenticated
  using (bucket_id='files') with check (bucket_id='files');

-- خدمات مبدئية
insert into services(title,description,sort_order) select * from (values
('تأسيس الشركات','اختيار الشكل القانوني المناسب، وإعداد العقود والنظام الأساسي، واستخراج السجل التجاري والبطاقة الضريبية حتى بدء النشاط.',1),
('قضايا ومنازعات الشركات','حل الخلافات بين الشركاء، وتحصيل المستحقات، وصياغة العقود ومراجعتها، وتمثيلك أمام المحاكم والتحكيم.',2),
('العقارات','فحص سلامة الملكية قبل الشراء، وتوثيق العقود وتسجيلها، والفصل في منازعات الإيجار والحيازة.',3) v(t,d,o) where not exists (select 1 from services);
