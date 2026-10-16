-- ============================================================
--  Photo de profil
-- ============================================================
--  Chemin dans le bucket `avatars` (pas une URL : le bucket est public,
--  l'app en déduit l'URL). Public en lecture comme sur Instagram : la
--  photo et le pseudo restent visibles même pour un profil privé, seuls
--  les moments sont protégés. Chacun n'écrit que dans son dossier.
-- ============================================================

alter table public.profils add column photo_url text;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "deposer sa photo de profil"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "remplacer sa photo de profil"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "retirer sa photo de profil"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
