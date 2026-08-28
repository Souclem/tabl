-- ============================================================
--  Corrections issues de la revue de code du 2026-08-25
-- ============================================================

-- ------------------------------------------------------------
--  1. abonnements : la policy UPDATE "accepter une demande" ne
--     vérifiait que auth.uid() = suivi_id, donc le destinataire
--     d'une demande pouvait réécrire n'importe quelle colonne de
--     la ligne, y compris réassigner suiveur_id à un autre profil
--     (le WITH CHECK ne portait que sur suivi_id, resté inchangé).
--     Remède : un GRANT au niveau colonne restreint ce qui est
--     modifiable à `statut`, quelle que soit la policy RLS —
--     `suiveur_id` et `suivi_id` deviennent immuables après
--     création, peu importe qui exécute l'UPDATE.
-- ------------------------------------------------------------

revoke update on public.abonnements from authenticated;
grant update (statut) on public.abonnements to authenticated;


-- ------------------------------------------------------------
--  2. La sous-requête "suis-je abonné-accepté à ce profil ?" était
--     dupliquée mot pour mot entre la policy de `souvenirs` et les
--     deux policies Storage. Une fonction SQL (pas PL/pgSQL, pas de
--     logique métier — un simple raccourci pour une condition RLS
--     déjà exprimée en SQL) évite que les deux endroits divergent.
-- ------------------------------------------------------------

create or replace function public.abonnement_accepte(cible uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.abonnements a
    where a.suiveur_id = auth.uid()
      and a.suivi_id = cible
      and a.statut = 'accepte'
  );
$$;

drop policy "lire les souvenirs de son cercle" on public.souvenirs;
create policy "lire les souvenirs de son cercle"
  on public.souvenirs for select
  to authenticated
  using (
    auteur_id = auth.uid()
    or public.abonnement_accepte(auteur_id)
  );

drop policy "voir les photos de son cercle" on storage.objects;
create policy "voir les photos de son cercle"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'souvenirs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.abonnement_accepte(((storage.foldername(name))[1])::uuid)
    )
  );
