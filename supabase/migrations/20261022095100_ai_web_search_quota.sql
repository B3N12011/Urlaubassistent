create table if not exists public.ai_search_usage_daily (
  day date not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  request_count integer not null default 0 check (request_count >= 0),
  primary key (day, user_id)
);

create table if not exists public.ai_search_global_usage_daily (
  day date primary key,
  request_count integer not null default 0 check (request_count >= 0)
);

alter table public.ai_search_usage_daily enable row level security;
alter table public.ai_search_global_usage_daily enable row level security;

revoke all on table public.ai_search_usage_daily from public, anon, authenticated;
revoke all on table public.ai_search_global_usage_daily from public, anon, authenticated;
grant all on table public.ai_search_usage_daily to service_role;
grant all on table public.ai_search_global_usage_daily to service_role;

create or replace function public.consume_ai_search_quota(
  p_user_id uuid,
  p_user_limit integer default 3,
  p_global_limit integer default 10
)
returns table (
  allowed boolean,
  user_remaining integer,
  global_remaining integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_day date := (now() at time zone 'utc')::date;
  v_user_count integer;
  v_global_count integer;
  v_user_limit integer := greatest(coalesce(p_user_limit, 3), 0);
  v_global_limit integer := greatest(coalesce(p_global_limit, 10), 0);
begin
  if p_user_id is null then
    return query select false, 0, 0;
    return;
  end if;

  insert into public.ai_search_global_usage_daily as g (day, request_count)
  values (v_day, 0)
  on conflict (day) do nothing;

  perform 1
  from public.ai_search_global_usage_daily as g
  where g.day = v_day
  for update;

  insert into public.ai_search_usage_daily as u (day, user_id, request_count)
  values (v_day, p_user_id, 0)
  on conflict (day, user_id) do nothing;

  perform 1
  from public.ai_search_usage_daily as u
  where u.day = v_day and u.user_id = p_user_id
  for update;

  select u.request_count into v_user_count
  from public.ai_search_usage_daily as u
  where u.day = v_day and u.user_id = p_user_id;

  select g.request_count into v_global_count
  from public.ai_search_global_usage_daily as g
  where g.day = v_day;

  if v_user_count >= v_user_limit or v_global_count >= v_global_limit then
    return query
      select false,
        greatest(v_user_limit - v_user_count, 0),
        greatest(v_global_limit - v_global_count, 0);
    return;
  end if;

  update public.ai_search_global_usage_daily as g
  set request_count = g.request_count + 1
  where g.day = v_day;

  update public.ai_search_usage_daily as u
  set request_count = u.request_count + 1
  where u.day = v_day and u.user_id = p_user_id;

  return query
    select true,
      greatest(v_user_limit - v_user_count - 1, 0),
      greatest(v_global_limit - v_global_count - 1, 0);
end;
$function$;

revoke all on function public.consume_ai_search_quota(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.consume_ai_search_quota(uuid, integer, integer) to service_role;
