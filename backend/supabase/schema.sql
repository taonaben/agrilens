-- Apply in the Supabase SQL editor before enabling FastAPI history sync.
-- All data access from Flutter is mediated by FastAPI. RLS is a second boundary.

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
create policy "owner reads conversations" on public.agrilens_conversations
  for select to authenticated using (owner_id = (select auth.uid()));
create policy "owner inserts conversations" on public.agrilens_conversations
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "owner updates conversations" on public.agrilens_conversations
  for update to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "owner deletes conversations" on public.agrilens_conversations
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy "owner manages messages" on public.agrilens_messages
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "owner manages predictions" on public.agrilens_predictions
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "owner manages deletion tombstones" on public.agrilens_conversation_deletions
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

-- Private bucket. Object names are <auth.uid>/<conversation UUID>/<message UUID>.<ext>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('agrilens-history', 'agrilens-history', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false;

create policy "owner reads history photos" on storage.objects
  for select to authenticated using (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "owner uploads history photos" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "owner updates history photos" on storage.objects
  for update to authenticated using (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  ) with check (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "owner deletes history photos" on storage.objects
  for delete to authenticated using (
    bucket_id = 'agrilens-history'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
