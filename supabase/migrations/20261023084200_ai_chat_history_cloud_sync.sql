create table if not exists public.ai_chat_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  scope_key text not null check (scope_key = 'general' or scope_key ~ '^trip:[0-9a-fA-F-]{36}$'),
  trip_id uuid null references public.trips(id) on delete cascade,
  messages jsonb not null default '[]'::jsonb check (jsonb_typeof(messages) = 'array'),
  updated_at timestamptz not null default now(),
  primary key (user_id, scope_key)
);

alter table public.ai_chat_history enable row level security;
revoke all on table public.ai_chat_history from public, anon;
grant select, insert, update, delete on table public.ai_chat_history to authenticated;

drop policy if exists "Users can read their own AI chat history" on public.ai_chat_history;
create policy "Users can read their own AI chat history"
on public.ai_chat_history for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own AI chat history" on public.ai_chat_history;
create policy "Users can insert their own AI chat history"
on public.ai_chat_history for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own AI chat history" on public.ai_chat_history;
create policy "Users can update their own AI chat history"
on public.ai_chat_history for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own AI chat history" on public.ai_chat_history;
create policy "Users can delete their own AI chat history"
on public.ai_chat_history for delete to authenticated
using ((select auth.uid()) = user_id);
