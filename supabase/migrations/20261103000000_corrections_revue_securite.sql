-- ============================================================
--  Revue de sécurité du 2026-11-02 : trois corrections de droits
-- ============================================================
--  1. Tables : un membre retiré, parti ou simplement invité pouvait
--     modifier toute sa ligne de `membres_table` (statut ET
--     est_admin) — donc se remettre actif et se rendre admin, puis
--     tout lire, retirer les autres ou supprimer la Table.
--  2. Lieux personnels : « lire les restaurants » était resté
--     `using (true)` → n'importe quel compte listait les lieux
--     personnels (nom libre) de tout le monde.
--  3. Photos (buckets `souvenirs` et `instants`) : un fichier se
--     lisait dès qu'une ligne visible pointait vers son chemin, sans
--     vérifier que ce chemin est dans le dossier de l'auteur de la
--     ligne → quelqu'un qui connaissait un chemin (ancien abonné,
--     membre retiré…) le rattachait à un brouillon à lui et gardait
--     l'accès.
-- ============================================================


-- ------------------------------------------------------------
--  1. membres_table : on ne change que son statut, et seulement
--     dans les transitions prévues
-- ------------------------------------------------------------
--  L'app ne modifie jamais que `statut` (accepter, refuser, quitter,
--  retirer). Soi-même : depuis « invité » ou « actif » uniquement,
--  vers « actif » (accepter) ou « parti » (refuser, quitter). Un admin
--  actif : réinviter ou retirer quelqu'un, jamais le faire entrer à
--  sa place.
revoke update on public.membres_table from authenticated;
grant update (statut) on public.membres_table to authenticated;

drop policy "repondre a une invitation, quitter, ou retirer un membre" on public.membres_table;
create policy "repondre a une invitation, quitter, ou retirer un membre"
  on public.membres_table for update
  to authenticated
  using (
    (profil_id = auth.uid() and statut in ('en_attente', 'active'))
    or public.est_admin_actif_table(table_id)
  )
  with check (
    (profil_id = auth.uid() and statut in ('active', 'parti'))
    or (
      public.est_admin_actif_table(table_id)
      and statut in ('en_attente', 'retire')
    )
  );

-- Parti ou retiré, on ne voit plus la Table ni ses membres (avant :
-- toute ligne, quel que soit son statut, suffisait).
create or replace function public.est_membre_table(p_table_id uuid)
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
      and statut in ('en_attente', 'active')
  );
$$;


-- ------------------------------------------------------------
--  2. restaurants : un lieu personnel ne se lit que par son auteur,
--     ou sur un souvenir qu'on a le droit de voir
-- ------------------------------------------------------------
--  Fonction security definer : la policy de `restaurants` ne relit
--  jamais une table elle-même (voir 20261102000000).
create or replace function public.lieu_personnel_visible(p_restaurant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.souvenirs s
    where s.restaurant_id = p_restaurant_id
      and public.peut_voir_souvenir(s.id)
  );
$$;

grant execute on function public.lieu_personnel_visible(uuid) to authenticated;

drop policy "lire les restaurants" on public.restaurants;
create policy "lire les restaurants"
  on public.restaurants for select
  to authenticated
  using (
    not prive
    or cree_par = auth.uid()
    or public.lieu_personnel_visible(id)
  );


-- ------------------------------------------------------------
--  3. Photos : le fichier doit être dans le dossier de l'auteur de
--     la ligne qui le désigne
-- ------------------------------------------------------------
--  Chaque dépôt se fait dans `{son id}/…` (policies d'insertion), donc
--  une ligne légitime pointe toujours dans le dossier de son auteur.
--  Exception : `demo/`, les photos libres de droits des données de
--  démonstration (scripts/photos_demo.py), que personne ne peut
--  déposer depuis l'app.

-- Corps de 20261026000000_souvenirs_du_passe.sql, plus le dossier.
drop policy "voir les photos des experiences visibles" on storage.objects;
create policy "voir les photos des experiences visibles"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'souvenirs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.souvenirs s
        where (s.photo_url = storage.objects.name or s.boisson_photo_url = storage.objects.name)
          and (storage.foldername(storage.objects.name))[1] in (s.auteur_id::text, 'demo')
          and public.peut_voir_souvenir(s.id)
      )
      or exists (
        select 1 from public.souvenirs_photos p
        join public.souvenirs s on s.id = p.souvenir_id
        where p.chemin = storage.objects.name
          and (storage.foldername(storage.objects.name))[1] in (s.auteur_id::text, 'demo')
          and public.peut_voir_souvenir(p.souvenir_id)
      )
    )
  );

-- Corps de 20260917040000_instants.sql, plus le dossier.
drop policy "voir les medias instants des experiences visibles" on storage.objects;
create policy "voir les medias instants des experiences visibles"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'instants'
    and exists (
      select 1 from public.instants i
      where i.media_url = storage.objects.name
        and (storage.foldername(storage.objects.name))[1] = i.owner_user_id::text
        and (i.owner_user_id = auth.uid() or public.peut_voir_souvenir(i.parent_experience_id))
    )
  );

-- La couverture d'une Table : un fichier déposé par un de ses admins
-- actifs (c'est lui qui la choisit), plus n'importe quel chemin.
drop policy "voir la cover des tables dont on est membre" on storage.objects;
create policy "voir la cover des tables dont on est membre"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'souvenirs'
    and exists (
      select 1
      from public.tables t
      join public.membres_table m
        on m.table_id = t.id and m.profil_id = auth.uid() and m.statut = 'active'
      join public.membres_table admin
        on admin.table_id = t.id and admin.statut = 'active' and admin.est_admin
      where t.couverture_photo_url = storage.objects.name
        and admin.profil_id::text = (storage.foldername(storage.objects.name))[1]
    )
  );
