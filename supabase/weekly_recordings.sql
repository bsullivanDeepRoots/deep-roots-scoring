-- Deep Roots IX: public recordings appear only after their mission unlocks.
create table if not exists public.weekly_recordings (
  week smallint primary key check (week between 1 and 8),
  url text not null check (url ~ '^https://[^[:space:]]+$' and length(url) <= 2048),
  passcode text not null check (length(passcode) between 1 and 128),
  updated_at timestamptz not null default now()
);
alter table public.weekly_recordings enable row level security;
grant select on public.weekly_recordings to anon, authenticated;
grant insert, update, delete on public.weekly_recordings to authenticated;

create policy "Visitors see released recordings with mission PDFs"
on public.weekly_recordings for select to public
using (
  now() >= public.deep_roots_mission_release_at('week-' || week || '.pdf')
  and exists (
    select 1 from storage.objects
    where bucket_id = 'weekly-missions'
      and name = 'week-' || week || '.pdf'
  )
);
create policy "Admin sees all recordings"
on public.weekly_recordings for select to authenticated
using ((auth.jwt() ->> 'email') = 'bsullivan@priorityone.org');
create policy "Admin adds recordings"
on public.weekly_recordings for insert to authenticated
with check ((auth.jwt() ->> 'email') = 'bsullivan@priorityone.org');
create policy "Admin edits recordings"
on public.weekly_recordings for update to authenticated
using ((auth.jwt() ->> 'email') = 'bsullivan@priorityone.org')
with check ((auth.jwt() ->> 'email') = 'bsullivan@priorityone.org');
create policy "Admin removes recordings"
on public.weekly_recordings for delete to authenticated
using ((auth.jwt() ->> 'email') = 'bsullivan@priorityone.org');
