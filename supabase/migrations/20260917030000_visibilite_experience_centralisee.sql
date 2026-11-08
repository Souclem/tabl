-- ============================================================
--  Visibilité centralisée — canViewExperience (megaprompt Bloc 5)
-- ============================================================
--  Principe central du bloc : AUDIENCE ≠ TABLE ASSOCIATION, mais toute
--  association Table est TOUJOURS aussi un grant de visibilité
--  (règle 5, 47). Avant ce bloc, deux mécanismes vivaient en parallèle :
--  - la policy `souvenirs` (migration `20260823000000...`) : auteur ou
--    cercle direct ;
--  - `experiences_table()` (migration `20260917010000_tables_groupes.sql`),
--    une fonction security-definer séparée qui élargissait la lecture
--    pour "Notre histoire", en contournant la policy plutôt qu'en la
--    complétant — un patch temporaire explicitement annoncé comme tel à
--    l'époque.
--
--  Ce bloc centralise en UN seul endroit (règle 92 : "Ne pas copier la
--  logique différente dans chaque écran") : `peut_voir_souvenir`. La
--  policy `souvenirs` l'appelle directement — c'est donc la même
--  évaluation qui protège la table pour tout le monde (Feed, Profil,
--  Table, Explorer/Map...), sans jamais dupliquer la règle ailleurs.
--
--  Signature : contrairement à la notation `canViewExperience(viewerId,
--  experienceId)` du texte, on garde `(p_souvenir_id)` seul et
--  `auth.uid()` en implicite — même convention que les 3 précédents déjà
--  établis dans ce projet (`abonnement_accepte`, `comptes_reseau_etendu`,
--  `experiences_table`, `resultats_disponibilite`) : côté client, on
--  n'évalue jamais la permission de quelqu'un d'autre que la session en
--  cours, un paramètre viewer explicite serait mort dès l'écriture.
-- ============================================================

create or replace function public.peut_voir_souvenir(p_souvenir_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.souvenirs s
    where s.id = p_souvenir_id
      and (
        -- Owner : toujours, quel que soit le statut (brouillon inclus).
        s.auteur_id = auth.uid()
        or (
          -- Audience de base CIRCLE (règle 4, 8).
          s.statut = 'publie'
          and s.visibilite = 'cercle'
          and public.abonnement_accepte(s.auteur_id)
        )
        or (
          -- Table grant (règle 5, 9-10) : membre actif d'au moins une
          -- Table à laquelle l'expérience est associée. Fonctionne aussi
          -- pour base_visibility = 'prive' (scénario "Table(s)
          -- uniquement", règle 11) : la base n'entre pas en jeu ici.
          s.statut = 'publie'
          and exists (
            select 1
            from public.associations_experience_table a
            join public.membres_table m
              on m.table_id = a.table_id
              and m.profil_id = auth.uid()
              and m.statut = 'active'
            where a.souvenir_id = s.id
          )
        )
      )
  );
$$;

grant execute on function public.peut_voir_souvenir(uuid) to authenticated;

-- La policy elle-même délègue entièrement à la fonction : un seul et
-- même calcul, qu'on lise `souvenirs` en direct (Feed, Profil) ou qu'on
-- passe par la fonction depuis un autre contexte (règle 92, ex. un futur
-- deep-link check qui n'a pas de droit de lecture directe sur la ligne).
-- Sûr contre la récursion : `peut_voir_souvenir` est security definer et
-- s'exécute donc avec les droits du propriétaire de la fonction, qui
-- contourne RLS pour sa propre lecture interne de `souvenirs` — la
-- policy ci-dessous n'est jamais réévaluée à l'intérieur de cet appel.
drop policy "lire les souvenirs de son cercle" on public.souvenirs;
create policy "lire les souvenirs de son cercle"
  on public.souvenirs for select
  to authenticated
  using (public.peut_voir_souvenir(id));

-- ============================================================
--  Retrait de l'ancien mécanisme ad hoc
-- ============================================================
--  Superseded par la policy `souvenirs` elle-même : un membre actif
--  d'une Table peut maintenant lire directement les lignes `souvenirs`
--  associées à cette Table (via `peut_voir_souvenir`), donc "Notre
--  histoire" n'a plus besoin de contourner RLS — une requête normale
--  suffit (voir `app/lib/services/tables/table_service_supabase.dart`,
--  méthodes `histoire`/`_cheminsPhotosRecents`, mises à jour en
--  conséquence dans ce même lot de travail).
-- ============================================================

drop function if exists public.experiences_table(uuid);

-- ============================================================
--  Owner control sur ses propres associations (règle 24, 37)
-- ============================================================
--  La policy de lecture posée au Bloc 3 ne couvrait que "membre actif de
--  la Table" — un owner qui quitte une Table après y avoir associé une
--  expérience (règle 37 : "il peut éventuellement retirer l'association
--  depuis la gestion de sa propre Experience") perdait alors le droit de
--  voir sa propre association, alors que le droit de la RETIRER
--  (policy delete, déjà posée au Bloc 3) restait correct. On aligne la
--  lecture sur le même principe : l'auteur de l'expérience garde
--  toujours la visibilité de ses propres associations, membre actif ou
--  non.
-- ============================================================

drop policy "lire les associations de ses tables" on public.associations_experience_table;
create policy "lire les associations de ses tables"
  on public.associations_experience_table for select
  to authenticated
  using (
    exists (
      select 1 from public.membres_table m
      where m.table_id = associations_experience_table.table_id
        and m.profil_id = auth.uid()
        and m.statut = 'active'
    )
    or exists (
      select 1 from public.souvenirs s
      where s.id = associations_experience_table.souvenir_id
        and s.auteur_id = auth.uid()
    )
  );
