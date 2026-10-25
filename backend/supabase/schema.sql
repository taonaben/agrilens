-- Apply in the Supabase SQL editor before enabling FastAPI history sync.
-- All data access from Flutter is mediated by FastAPI. RLS is a second boundary.

create schema if not exists extensions;
create extension if not exists vector with schema extensions;
grant usage on schema extensions to authenticated;

create table if not exists public.agrilens_conversations (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.agrilens_messages (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.agrilens_conversations(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content_type text not null check (content_type in ('text', 'image')),
  text_content text,
  image_object_path text,
  lifecycle text not null check (lifecycle in ('pending', 'complete', 'failed')),
  failure_reason text,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  constraint agrilens_image_message_path check (
    content_type <> 'image' or image_object_path is not null or lifecycle <> 'complete'
  )
);

create table if not exists public.agrilens_predictions (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null unique references public.agrilens_messages(id) on delete cascade,
  class_id integer not null check (class_id between 0 and 8),
  crop text not null check (crop in ('maize', 'tomato')),
  condition text not null,
  decision_state text not null check (decision_state in ('possibleMatch', 'uncertain', 'unsupportedOrUnclear')),
  top_logit double precision not null,
  calibrated_score double precision not null check (calibrated_score between 0 and 1),
  margin double precision not null check (margin between 0 and 1),
  prototype_similarity double precision,
  model_version text not null,
  preprocess_version text not null,
  failure_reason text,
  created_at timestamptz not null
);

-- Tombstones preserve offline conversation deletions until other devices sync.
create table if not exists public.agrilens_conversation_deletions (
  conversation_id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  deleted_at timestamptz not null default now()
);

create index if not exists agrilens_conversations_owner_updated
  on public.agrilens_conversations(owner_id, updated_at desc);
create index if not exists agrilens_messages_owner_conversation_created
  on public.agrilens_messages(owner_id, conversation_id, created_at);
create index if not exists agrilens_deletions_owner_deleted
  on public.agrilens_conversation_deletions(owner_id, deleted_at);

alter table public.agrilens_conversations enable row level security;
alter table public.agrilens_messages enable row level security;
alter table public.agrilens_predictions enable row level security;
alter table public.agrilens_conversation_deletions enable row level security;

-- Supabase Auth user tokens forwarded by FastAPI remain scoped to their owner.
drop policy if exists "owner reads conversations" on public.agrilens_conversations;
create policy "owner reads conversations" on public.agrilens_conversations
  for select to authenticated using (owner_id = (select auth.uid()));
drop policy if exists "owner inserts conversations" on public.agrilens_conversations;
create policy "owner inserts conversations" on public.agrilens_conversations
  for insert to authenticated with check (owner_id = (select auth.uid()));
drop policy if exists "owner updates conversations" on public.agrilens_conversations;
create policy "owner updates conversations" on public.agrilens_conversations
  for update to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
drop policy if exists "owner deletes conversations" on public.agrilens_conversations;
create policy "owner deletes conversations" on public.agrilens_conversations
  for delete to authenticated using (owner_id = (select auth.uid()));

drop policy if exists "owner manages messages" on public.agrilens_messages;
create policy "owner manages messages" on public.agrilens_messages
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
drop policy if exists "owner manages predictions" on public.agrilens_predictions;
create policy "owner manages predictions" on public.agrilens_predictions
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
drop policy if exists "owner manages deletion tombstones" on public.agrilens_conversation_deletions;
create policy "owner manages deletion tombstones" on public.agrilens_conversation_deletions
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

-- Private bucket. Object names are <auth.uid>/<conversation UUID>/<message UUID>.<ext>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('agrilens-history', 'agrilens-history', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false;

drop policy if exists "owner reads history photos" on storage.objects;
create policy "owner reads history photos" on storage.objects
  for select to authenticated using (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
drop policy if exists "owner uploads history photos" on storage.objects;
create policy "owner uploads history photos" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
drop policy if exists "owner updates history photos" on storage.objects;
create policy "owner updates history photos" on storage.objects
  for update to authenticated using (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  ) with check (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
drop policy if exists "owner deletes history photos" on storage.objects;
create policy "owner deletes history photos" on storage.objects
  for delete to authenticated using (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Shop catalog and farmer orders. Catalog writes use the backend service role;
-- authenticated farmers can only read active products and their own orders.
create table if not exists public.shop_products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique,
  name text not null,
  description text not null default '',
  price numeric(12,2) not null check (price > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  crops text[] not null default '{}',
  conditions text[] not null default '{}',
  recommended_uses text[] not null default '{}',
  evidence_source_url text,
  evidence_reviewed_at date,
  stock_verified_at date,
  recommendation_eligible boolean not null default false,
  search_embedding extensions.vector(768),
  search_embedding_model text,
  image_path text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.shop_products add column if not exists image_path text;
alter table public.shop_products add column if not exists recommended_uses text[] not null default '{}';
alter table public.shop_products add column if not exists evidence_source_url text;
alter table public.shop_products add column if not exists evidence_reviewed_at date;
alter table public.shop_products add column if not exists stock_verified_at date;
alter table public.shop_products add column if not exists recommendation_eligible boolean not null default false;
alter table public.shop_products add column if not exists search_embedding extensions.vector(768);
alter table public.shop_products add column if not exists search_embedding_model text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'shop_products_recommendation_evidence') then
    alter table public.shop_products add constraint shop_products_recommendation_evidence check (
      not recommendation_eligible or (
        cardinality(crops) > 0 and cardinality(recommended_uses) > 0
        and evidence_source_url is not null and evidence_reviewed_at is not null
        and stock_verified_at is not null and search_embedding is not null
        and search_embedding_model is not null
      )
    );
  end if;
end $$;

create index if not exists shop_products_active_name on public.shop_products(active, name);
create index if not exists shop_products_search_embedding_hnsw
  on public.shop_products using hnsw (search_embedding extensions.vector_cosine_ops)
  where recommendation_eligible and active and stock_quantity > 0;
alter table public.shop_products enable row level security;
drop policy if exists "authenticated reads active shop products" on public.shop_products;
create policy "authenticated reads active shop products" on public.shop_products
  for select to authenticated using (active = true);

create table if not exists public.agrilens_guidance_chunks (
  id uuid primary key default gen_random_uuid(),
  source_url text not null,
  chunk_index integer not null check (chunk_index >= 0),
  source_title text not null,
  source_organization text not null,
  source_published_on date,
  reviewed_on date not null,
  topic text not null,
  crop text not null,
  condition text,
  content text not null,
  is_approved boolean not null default false,
  embedding extensions.vector(768),
  embedding_model text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_url, chunk_index),
  check (not is_approved or (embedding is not null and embedding_model is not null))
);

alter table public.agrilens_guidance_chunks enable row level security;
drop policy if exists "authenticated reads approved agronomy guidance" on public.agrilens_guidance_chunks;
create policy "authenticated reads approved agronomy guidance" on public.agrilens_guidance_chunks
  for select to authenticated using (is_approved = true);
grant select on public.agrilens_guidance_chunks to authenticated;

create index if not exists agrilens_guidance_embedding_hnsw
  on public.agrilens_guidance_chunks using hnsw (embedding extensions.vector_cosine_ops)
  where is_approved;

create or replace function public.search_verified_products(
  query_embedding text, model_name text, match_count integer default 8
)
returns table (
  id uuid, sku text, name text, description text, price numeric, currency text,
  stock_quantity integer, crops text[], conditions text[], recommended_uses text[],
  evidence_source_url text, evidence_reviewed_at date, stock_verified_at date,
  image_path text, similarity double precision
)
language sql stable security invoker
set search_path = public, extensions
as $$
  select p.id, p.sku, p.name, p.description, p.price, p.currency,
         p.stock_quantity, p.crops, p.conditions, p.recommended_uses,
         p.evidence_source_url, p.evidence_reviewed_at, p.stock_verified_at,
         p.image_path, 1 - (p.search_embedding <=> query_embedding::extensions.vector(768))
  from public.shop_products p
  where p.active and p.recommendation_eligible and p.stock_quantity > 0
    and p.search_embedding is not null
    and p.search_embedding_model = model_name
  order by p.search_embedding <=> query_embedding::extensions.vector(768)
  limit least(greatest(match_count, 0), 8);
$$;

create or replace function public.search_reviewed_guidance(
  query_embedding text, model_name text, match_count integer default 8
)
returns table (
  id uuid, source_url text, source_title text, source_organization text,
  source_published_on date, reviewed_on date, topic text, crop text,
  condition text, content text, similarity double precision
)
language sql stable security invoker
set search_path = public, extensions
as $$
  select g.id, g.source_url, g.source_title, g.source_organization,
         g.source_published_on, g.reviewed_on, g.topic, g.crop, g.condition,
         g.content, 1 - (g.embedding <=> query_embedding::extensions.vector(768))
  from public.agrilens_guidance_chunks g
  where g.is_approved and g.embedding is not null
    and g.embedding_model = model_name
  order by g.embedding <=> query_embedding::extensions.vector(768)
  limit least(greatest(match_count, 0), 8);
$$;

revoke all on function public.search_verified_products(text, text, integer) from public, anon;
revoke all on function public.search_reviewed_guidance(text, text, integer) from public, anon;
grant execute on function public.search_verified_products(text, text, integer) to authenticated;
grant execute on function public.search_reviewed_guidance(text, text, integer) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('agrilens-products', 'agrilens-products', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

create table if not exists public.agrilens_user_crops (
  owner_id uuid not null references auth.users(id) on delete cascade,
  crop text not null check (crop in ('maize', 'tomato')),
  created_at timestamptz not null default now(),
  primary key (owner_id, crop)
);
alter table public.agrilens_user_crops enable row level security;
drop policy if exists "owners read their crop preferences" on public.agrilens_user_crops;
create policy "owners read their crop preferences" on public.agrilens_user_crops
  for select to authenticated using (owner_id = (select auth.uid()));

create or replace function public.set_agrilens_user_crops(p_crops text[]) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_owner uuid := auth.uid();
begin
  if v_owner is null then raise exception 'Authentication required'; end if;
  if exists (select 1 from unnest(p_crops) as u(crop) where u.crop not in ('maize', 'tomato')) then
    raise exception 'Unsupported crop';
  end if;
  delete from public.agrilens_user_crops where owner_id = v_owner;
  insert into public.agrilens_user_crops(owner_id, crop)
    select v_owner, crop from (select distinct unnest(p_crops) as crop) selected;
end;
$$;
revoke all on function public.set_agrilens_user_crops(text[]) from public;
grant execute on function public.set_agrilens_user_crops(text[]) to authenticated;

create table if not exists public.shop_orders (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  contact_name text not null,
  phone text not null,
  delivery_address text not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'fulfilled', 'cancelled')),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  total_amount numeric(12,2) not null check (total_amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.shop_orders(id) on delete cascade,
  product_id uuid references public.shop_products(id) on delete set null,
  sku_snapshot text not null,
  name_snapshot text not null,
  unit_price numeric(12,2) not null check (unit_price > 0),
  quantity integer not null check (quantity > 0),
  line_total numeric(12,2) not null check (line_total > 0),
  created_at timestamptz not null default now()
);

create or replace function public.set_shop_updated_at() returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists shop_products_updated_at on public.shop_products;
create trigger shop_products_updated_at before update on public.shop_products
  for each row execute function public.set_shop_updated_at();
drop trigger if exists shop_orders_updated_at on public.shop_orders;
create trigger shop_orders_updated_at before update on public.shop_orders
  for each row execute function public.set_shop_updated_at();
drop trigger if exists agrilens_guidance_updated_at on public.agrilens_guidance_chunks;
create trigger agrilens_guidance_updated_at before update on public.agrilens_guidance_chunks
  for each row execute function public.set_shop_updated_at();

create index if not exists shop_orders_owner_created on public.shop_orders(owner_id, created_at desc);
create index if not exists shop_order_items_order on public.shop_order_items(order_id);
alter table public.shop_orders enable row level security;
alter table public.shop_order_items enable row level security;
drop policy if exists "owners read shop orders" on public.shop_orders;
create policy "owners read shop orders" on public.shop_orders
  for select to authenticated using (owner_id = (select auth.uid()));
drop policy if exists "owners read their shop order items" on public.shop_order_items;
create policy "owners read their shop order items" on public.shop_order_items
  for select to authenticated using (
    exists (select 1 from public.shop_orders o where o.id = order_id and o.owner_id = (select auth.uid()))
  );

-- Stock reservation and order snapshots are committed as one transaction.
create or replace function public.create_shop_order(
  p_items jsonb,
  p_contact_name text,
  p_phone text,
  p_delivery_address text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_order_id uuid := gen_random_uuid();
  v_item jsonb;
  v_product public.shop_products%rowtype;
  v_quantity integer;
  v_currency text;
  v_total numeric(12,2) := 0;
begin
  if v_owner is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 50 then
    raise exception 'Order must contain between 1 and 50 items';
  end if;
  if nullif(trim(p_contact_name), '') is null or nullif(trim(p_phone), '') is null
    or nullif(trim(p_delivery_address), '') is null then raise exception 'Delivery details are required'; end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_quantity := (v_item->>'quantity')::integer;
    if v_quantity < 1 or v_quantity > 1000 then raise exception 'Invalid quantity'; end if;
    select * into v_product from public.shop_products
      where id = (v_item->>'product_id')::uuid and active = true for update;
    if not found then raise exception 'Product is unavailable'; end if;
    if v_product.stock_quantity < v_quantity then raise exception 'Insufficient stock for %', v_product.name; end if;
    if v_currency is null then v_currency := v_product.currency;
    elsif v_currency <> v_product.currency then raise exception 'Order products must use one currency'; end if;
    v_total := v_total + v_product.price * v_quantity;
  end loop;

  insert into public.shop_orders(owner_id, contact_name, phone, delivery_address, currency, total_amount)
    values (v_owner, trim(p_contact_name), trim(p_phone), trim(p_delivery_address), v_currency, v_total)
    returning id into v_order_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_quantity := (v_item->>'quantity')::integer;
    select * into v_product from public.shop_products
      where id = (v_item->>'product_id')::uuid and active = true for update;
    update public.shop_products set stock_quantity = stock_quantity - v_quantity, updated_at = now()
      where id = v_product.id;
    insert into public.shop_order_items(order_id, product_id, sku_snapshot, name_snapshot, unit_price, quantity, line_total)
      values (v_order_id, v_product.id, v_product.sku, v_product.name, v_product.price, v_quantity, v_product.price * v_quantity);
  end loop;
  return v_order_id;
end;
$$;

revoke all on function public.create_shop_order(jsonb, text, text, text) from public;
grant execute on function public.create_shop_order(jsonb, text, text, text) to authenticated;

notify pgrst, 'reload schema';
