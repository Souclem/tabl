-- ============================================================
--  Storage — photos des souvenirs
-- ============================================================
--  Bucket privé : pas de lecture publique par URL directe, cohérent
--  avec « Tabl est privé ». Chemin de stockage : {auteur_id}/{fichier}
--  — le premier segment du chemin EST l'auteur, donc les mêmes règles
--  de visibilité que la table souvenirs (auteur + abonnés acceptés)
--  s'appliquent sans avoir besoin de la joindre.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('souvenirs', 'souvenirs', false, 10485760, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

-- Dépôt : uniquement dans son propre dossier (premier segment du chemin
-- = son propre id).
create policy "deposer sa propre photo"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'souvenirs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Lecture : ses propres photos, ou celles de qui on suit avec un
-- abonnement accepté.
create policy "voir les photos de son cercle"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'souvenirs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.abonnements a
        where a.suiveur_id = auth.uid()
          and a.suivi_id = ((storage.foldername(name))[1])::uuid
          and a.statut = 'accepte'
      )
    )
  );

-- Pas d'update ni de delete pour l'instant.
