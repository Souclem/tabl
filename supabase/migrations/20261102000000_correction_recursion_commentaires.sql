-- ============================================================
--  Correction — récursion infinie dans la policy d'insertion de
--  `commentaires` (plus personne ne pouvait commenter)
-- ============================================================
--  `20261101010000_commentaires_reponses_et_jaime.sql` a reposé
--  « commenter un souvenir visible » avec une vérification de la
--  réponse : son parent doit être un commentaire du même moment, qui
--  n'est pas lui-même une réponse. Elle le vérifiait par un
--  `select ... from public.commentaires` — posé SUR `commentaires`.
--  Postgres refuse toute policy qui relit sa propre table (SQLSTATE
--  42P17, « infinite recursion detected in policy for relation
--  "commentaires" »), et pas seulement pour les réponses : chaque
--  commentaire était refusé. Vu en testant l'app contre la base
--  distante, jamais dans flutter test (le service y est simulé).
--
--  Correction : le même principe que `est_membre_table` — une
--  fonction security definer fait cette lecture-là sans RLS, donc
--  sans repasser par la policy. Elle ne répond que par oui ou non, et
--  la policy exige toujours que le moment soit visible.
-- ============================================================

create or replace function public.est_commentaire_racine(
  p_commentaire_id uuid,
  p_souvenir_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.commentaires
    where id = p_commentaire_id
      and souvenir_id = p_souvenir_id
      and parent_id is null
  );
$$;

grant execute on function public.est_commentaire_racine(uuid, uuid)
  to authenticated;

drop policy "commenter un souvenir visible" on public.commentaires;

create policy "commenter un souvenir visible"
  on public.commentaires for insert
  to authenticated
  with check (
    auteur_id = auth.uid()
    and exists (
      select 1 from public.souvenirs s
      where s.id = commentaires.souvenir_id
    )
    -- Une réponse répond à un commentaire du même moment, qui n'est pas
    -- lui-même une réponse.
    and (
      parent_id is null
      or public.est_commentaire_racine(parent_id, souvenir_id)
    )
  );
