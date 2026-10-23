create table if not exists public.ai_chat_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id uuid,
  title text not null default 'Neuer Chat' check (char_length(title) <= 120),
  messages jsonb not null default '[]'::jsonb check (jsonb_typeof(messages) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ai_chat_conversations_user_updated_idx
  on public.ai_chat_conversations (user_id, updated_at desc);
create index if not exists ai_chat_conversations_user_trip_updated_idx
  on public.ai_chat_conversations (user_id, trip_id, updated_at desc);

alter table public.ai_chat_conversations enable row level security;
revoke all on table public.ai_chat_conversations from public, anon;
grant select, insert, update, delete on table public.ai_chat_conversations to authenticated;

drop policy if exists "Users can read their own AI chats" on public.ai_chat_conversations;
create policy "Users can read their own AI chats"
  on public.ai_chat_conversations for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own AI chats" on public.ai_chat_conversations;
create policy "Users can create their own AI chats"
  on public.ai_chat_conversations for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own AI chats" on public.ai_chat_conversations;
create policy "Users can update their own AI chats"
  on public.ai_chat_conversations for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own AI chats" on public.ai_chat_conversations;
create policy "Users can delete their own AI chats"
  on public.ai_chat_conversations for delete to authenticated
  using ((select auth.uid()) = user_id);
