-- ============================================================
--  Correction — une proposition devient orpheline si son créateur
--  quitte ou est retiré de la Table (megaprompt Bloc 4, écart trouvé
--  en audit : aucune policy n'avait de repli sur un admin)
-- ============================================================
--  Toutes les actions de gestion d'une proposition (dates candidates,
--  confirmation, heure, inspection des réponses brutes, mini-chat)
--  ne vérifiaient que `cree_par = auth.uid()`. Si ce créateur quitte
--  la Table, plus personne ne peut jamais confirmer/modifier ses
--  propositions en cours — elles restent bloquées pour toujours.
--
--  Correction : le créateur garde toujours ses droits, ET tout admin
--  actif de la Table peut aussi agir en repli — même principe que
--  `est_admin_actif_table` (Bloc 3, correction précédente).
-- ============================================================

create or replace function public.peut_gerer_proposition(p_proposition_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.table_propositions p
    where p.id = p_proposition_id
      and (
        p.cree_par = auth.uid()
        or public.est_admin_actif_table(p.table_id)
      )
  );
$$;

grant execute on function public.peut_gerer_proposition(uuid) to authenticated;


-- confirmations_proposition ----------------------------------------

drop policy "creator confirme une date" on public.confirmations_proposition;
create policy "creator ou admin confirme une date"
  on public.confirmations_proposition for insert
  to authenticated
  with check (
    confirme_par = auth.uid()
    and public.peut_gerer_proposition(proposition_id)
  );

drop policy "creator ajoute ou change l'heure" on public.confirmations_proposition;
create policy "creator ou admin ajoute ou change l'heure"
  on public.confirmations_proposition for update
  to authenticated
  using (public.peut_gerer_proposition(proposition_id))
  with check (public.peut_gerer_proposition(proposition_id));

drop policy "creator retire la confirmation pour replanifier" on public.confirmations_proposition;
create policy "creator ou admin retire la confirmation pour replanifier"
  on public.confirmations_proposition for delete
  to authenticated
  using (public.peut_gerer_proposition(proposition_id));


-- dates_candidates_proposition ---------------------------------------

drop policy "creator propose des dates tant que non confirme" on public.dates_candidates_proposition;
create policy "creator ou admin propose des dates tant que non confirme"
  on public.dates_candidates_proposition for insert
  to authenticated
  with check (
    public.peut_gerer_proposition(proposition_id)
    and not exists (
      select 1 from public.confirmations_proposition c
      where c.proposition_id = dates_candidates_proposition.proposition_id
    )
  );

drop policy "creator retire une date tant que non confirme" on public.dates_candidates_proposition;
create policy "creator ou admin retire une date tant que non confirme"
  on public.dates_candidates_proposition for delete
  to authenticated
  using (
    public.peut_gerer_proposition(proposition_id)
    and not exists (
      select 1 from public.confirmations_proposition c
      where c.proposition_id = dates_candidates_proposition.proposition_id
    )
  );


-- disponibilites_soumises / disponibilites_proposition : lecture ------
-- Règle 23/67 : le creator peut inspecter qui a répondu quoi ; même
-- repli admin si le creator est parti.

drop policy "lire sa propre reponse ou celles de ses propositions" on public.disponibilites_soumises;
create policy "lire sa propre reponse ou celles geree par creator/admin"
  on public.disponibilites_soumises for select
  to authenticated
  using (
    profil_id = auth.uid()
    or public.peut_gerer_proposition(proposition_id)
  );

drop policy "lire sa propre disponibilite ou celles de ses propositions" on public.disponibilites_proposition;
create policy "lire sa propre disponibilite ou celles geree par creator/admin"
  on public.disponibilites_proposition for select
  to authenticated
  using (
    profil_id = auth.uid()
    or exists (
      select 1 from public.dates_candidates_proposition d
      where d.id = disponibilites_proposition.date_candidate_id
        and public.peut_gerer_proposition(d.proposition_id)
    )
  );


-- table_propositions : annuler ---------------------------------------
-- Même repli pour annuler une proposition bloquée par un créateur parti.

drop policy "annuler sa propre proposition" on public.table_propositions;
create policy "creator ou admin annule une proposition"
  on public.table_propositions for update
  to authenticated
  using (public.peut_gerer_proposition(id))
  with check (public.peut_gerer_proposition(id));


-- messages_organisation : accès du creator, avec repli admin ----------

create or replace function public.peut_acceder_organisation(p_proposition_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select public.peut_gerer_proposition(p_proposition_id)
  or exists (
    select 1 from public.interets_proposition i
    join public.table_propositions p on p.id = i.proposition_id
    join public.membres_table m
      on m.table_id = p.table_id and m.profil_id = auth.uid() and m.statut = 'active'
    where i.proposition_id = p_proposition_id
      and i.profil_id = auth.uid()
      and i.interet = 'go'
  );
$$;
