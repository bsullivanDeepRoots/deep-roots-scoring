-- Run once in the Supabase SQL Editor for project kbwgbdonltdwvxrjawkl.
-- Limit management to the Deep Roots administrator account.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('weekly-missions', 'weekly-missions', false, 20971520, array['application/pdf'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- The storage server evaluates the unlock time. Browser clocks and page source
-- cannot reveal or download a future PDF from this private bucket.
create or replace function public.deep_roots_mission_release_at(file_name text)
returns timestamptz
language sql stable
set search_path = ''
as $$
  select case when file_name ~ '^week-[1-8][.]pdf$' then
    ((date '2026-09-18' +
      ((substring(file_name from '^week-([1-8])[.]pdf$')::integer - 1) * 7))::timestamp
      + interval '12 hours') at time zone 'America/New_York'
  else null end;
$$;
grant execute on function public.deep_roots_mission_release_at(text) to anon, authenticated;

drop policy if exists "Released missions visible to visitors" on storage.objects;
create policy "Released missions visible to visitors" on storage.objects
for select to public
using (
  bucket_id = 'weekly-missions'
  and now() >= public.deep_roots_mission_release_at(name)
);

drop policy if exists "Admins view all mission PDFs" on storage.objects;
create policy "Admins view all mission PDFs" on storage.objects
for select to authenticated
using (bucket_id = 'weekly-missions' and (auth.jwt() ->> 'email') = 'bsullivan@priorityone.org');

drop policy if exists "Admins upload mission PDFs" on storage.objects;
create policy "Admins upload mission PDFs" on storage.objects
for insert to authenticated
with check (bucket_id = 'weekly-missions' and name ~ '^week-[1-8][.]pdf$' and (auth.jwt() ->> 'email') = 'bsullivan@priorityone.org');

drop policy if exists "Admins replace mission PDFs" on storage.objects;
create policy "Admins replace mission PDFs" on storage.objects
for update to authenticated
using (bucket_id = 'weekly-missions' and (auth.jwt() ->> 'email') = 'bsullivan@priorityone.org')
with check (bucket_id = 'weekly-missions' and name ~ '^week-[1-8][.]pdf$' and (auth.jwt() ->> 'email') = 'bsullivan@priorityone.org');

drop policy if exists "Admins remove mission PDFs" on storage.objects;
create policy "Admins remove mission PDFs" on storage.objects
for delete to authenticated
using (bucket_id = 'weekly-missions' and (auth.jwt() ->> 'email') = 'bsullivan@priorityone.org');
