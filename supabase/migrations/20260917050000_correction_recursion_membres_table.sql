-- ============================================================
--  Correction — récursion infinie dans les policies de
--  `membres_table` (bug réel découvert en testant l'app pour de
--  vrai contre la base distante, jamais visible dans flutter test)
-- ============================================================
--  Les 3 policies de `membres_table` posées dans
--  `20260917010000_tables_groupes.sql` s'auto-référencent : leur
--  USING/WITH CHECK fait `select ... from public.membres_table`
--  alors qu'elles sont posées SUR `membres_table` elle-même — chaque
--  lecture de la table déclenche une réévaluation de sa propre
--  policy, à l'infini. Postgres le détecte et refuse la requête
--  (SQLSTATE 42P17) plutôt que de boucler.
--
--  Conséquence en cascade : toute requête touchant `membres_table`,
--  même indirectement (l'écran Tables, mais aussi les 2 policies
--  Storage du même fichier qui la traversent pour la mosaïque —
--  d'où le Feed cassé alors que rien n'a changé côté Feed).
--
--  Correction : même principe déjà établi ailleurs dans ce projet
--  (`abonnement_accepte`, `peut_voir_souvenir`...) — une fonction
--  security definer bypass RLS pour SA PROPRE lecture interne de la
--  table, donc ne se re-déclenche jamais elle-même.
-- ============================================================

create or replace function public.est_membre_table(p_table_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.membres_table
    where table_id = p_table_id and profil_id = auth.uid()
  );
$$;

grant execute on function public.est_membre_table(uuid) to authenticated;

create or replace function public.est_admin_actif_table(p_table_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.membres_table
    where table_id = p_table_id
      and profil_id = auth.uid()
      and statut = 'active'
      and est_admin
  );
$$;

grant execute on function public.est_admin_actif_table(uuid) to authenticated;

drop policy "lire les membres de ses tables" on public.membres_table;
create policy "lire les membres de ses tables"
  on public.membres_table for select
  to authenticated
  using (public.est_membre_table(table_id));

drop policy "creer une invitation ou se rejoindre a la creation" on public.membres_table;
create policy "creer une invitation ou se rejoindre a la creation"
  on public.membres_table for insert
  to authenticated
  with check (
    (
      profil_id = auth.uid()
      and exists (
        select 1 from public.tables t
        where t.id = membres_table.table_id and t.cree_par = auth.uid()
      )
    )
    or public.est_admin_actif_table(table_id)
  );

drop policy "repondre a une invitation, quitter, ou retirer un membre" on public.membres_table;
create policy "repondre a une invitation, quitter, ou retirer un membre"
  on public.membres_table for update
  to authenticated
  using (profil_id = auth.uid() or public.est_admin_actif_table(table_id))
  with check (profil_id = auth.uid() or public.est_admin_actif_table(table_id));
