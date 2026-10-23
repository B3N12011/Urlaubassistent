
create table if not exists public.ai_saved_chats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope_key text not null,
  trip_id uuid null references public.trips(id) on delete cascade,
  title text not null default 'Urlaub-Chat' check (char_length(btrim(title)) between 1 and 100),
  messages jsonb not null default '[]'::jsonb check (jsonb_typeof(messages) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.ai_saved_chats enable row level security;
revoke all on table public.ai_saved_chats from public, anon;
grant select, insert, update, delete on table public.ai_saved_chats to authenticated;

drop policy if exists "Users can read their own saved AI chats" on public.ai_saved_chats;
create policy "Users can read their own saved AI chats"
on public.ai_saved_chats for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own saved AI chats" on public.ai_saved_chats;
create policy "Users can insert their own saved AI chats"
on public.ai_saved_chats for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own saved AI chats" on public.ai_saved_chats;
create policy "Users can update their own saved AI chats"
on public.ai_saved_chats for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own saved AI chats" on public.ai_saved_chats;
create policy "Users can delete their own saved AI chats"
on public.ai_saved_chats for delete to authenticated
using ((select auth.uid()) = user_id);

create index if not exists ai_saved_chats_user_trip_updated_idx
on public.ai_saved_chats (user_id, trip_id, updated_at desc);
