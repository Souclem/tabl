-- ============================================================
--  Tables — espaces privés orientés restaurants (megaprompt Bloc 3)
-- ============================================================
--  "Table" est le terme produit ("Vos Tables", "Marbella", "Les gars").
--  Côté Dart le modèle s'appelle `GroupeTable` pour ne pas entrer en
--  collision avec `Table` du SDK Flutter — voir
--  `app/lib/services/tables/groupe_table.dart`. Rien n'empêche ce nom
--  ici en SQL : `tables` (pluriel) n'est pas un mot réservé.
--
--  Modèle repris de la section 48 du megaprompt (Table /
--  TableMembership / ExperienceTableAssociation / TableProposal), avec
--  le lifecycle complet des propositions (règle 32) dès cette migration
--  pour ne pas avoir à retoucher la contrainte au Bloc 4 — Bloc 3
--  n'utilise que 'active' et les états terminaux, Bloc 4 ajoutera les
--  transitions 'polling'/'date_selection'/'confirmed'/'completed'.
-- ============================================================

create table public.tables (
  id uuid primary key default gen_random_uuid(),

  nom text not null,
  emoji text,
  -- Signature optionnelle (règle 18) : jamais un champ bio forcé.
  signature text,
  -- Chemin dans le bucket `souvenirs` (même bucket, même politique de
  -- résolution en URL signée que les photos de souvenirs) — cover
  -- manuelle choisie par un admin, gagne toujours sur la mosaïque
  -- (règle 11-12).
  couverture_photo_url text,

  cree_par uuid not null references public.profils (id) on delete set null,
  cree_le timestamptz not null default now(),
  maj_le timestamptz not null default now()
);

-- membres_table (définition complète et ses propres policies plus
-- bas) est créée ICI, immédiatement, et non à sa place logique
-- après les policies de `tables` : ces policies la référencent dans
-- leur USING/WITH CHECK, et Postgres résout une policy à sa création
-- — la relation référencée doit donc déjà exister à ce moment précis,
-- pas seulement plus loin dans le fichier. Un `db push` réel contre
-- Postgres l'a révélé (SQLSTATE 42P01) là où `flutter test`, qui ne
-- parle jamais à une vraie base, ne pouvait pas l'attraper.
create table public.membres_table (
  id uuid primary key default gen_random_uuid(),
  table_id uuid not null references public.tables (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,

  -- Créateur = admin initial (règle 56) ; "en_attente" = invitation
  -- envoyée, pas encore un membre actif (règle 49, 54).
  statut text not null default 'en_attente'
    check (statut in ('en_attente', 'active', 'parti', 'retire')),
  est_admin boolean not null default false,

  rejoint_le timestamptz not null default now(),

  unique (table_id, profil_id)
);

grant select, insert, update, delete on public.tables to authenticated;

alter table public.tables enable row level security;

create policy "lire les tables dont on est membre"
  on public.tables for select
  to authenticated
  using (
    exists (
      select 1 from public.membres_table m
      where m.table_id = tables.id and m.profil_id = auth.uid()
    )
  );

create policy "creer une table"
  on public.tables for insert
  to authenticated
  with check (cree_par = auth.uid());

-- Renommer / changer la cover / supprimer : admin actif uniquement
-- (règle 56). Pas de policy delete séparée : `delete` utilise `using`,
-- déjà couvert ci-dessous par la même condition que l'update.
create policy "administrer sa table"
  on public.tables for update
  to authenticated
  using (
    exists (
      select 1 from public.membres_table m
      where m.table_id = tables.id
        and m.profil_id = auth.uid()
        and m.statut = 'active'
        and m.est_admin
    )
  )
  with check (
    exists (
      select 1 from public.membres_table m
      where m.table_id = tables.id
        and m.profil_id = auth.uid()
        and m.statut = 'active'
        and m.est_admin
    )
  );

create policy "supprimer sa table"
  on public.tables for delete
  to authenticated
  using (
    exists (
      select 1 from public.membres_table m
      where m.table_id = tables.id
        and m.profil_id = auth.uid()
        and m.statut = 'active'
        and m.est_admin
    )
  );


-- ============================================================
--  membres_table — TableMembership (règle 48-49, 54, 57-58)
-- ============================================================
--  Table déjà créée plus haut, juste après `public.tables` (voir le
--  commentaire à cet endroit) — ici, uniquement ses propres policies.
-- ============================================================

grant select, insert, update on public.membres_table to authenticated;

alter table public.membres_table enable row level security;

-- Lecture : seuls les membres (quel que soit leur statut, un invité doit
-- voir la Table à laquelle il est invité) voient la liste des membres.
create policy "lire les membres de ses tables"
  on public.membres_table for select
  to authenticated
  using (
    exists (
      select 1 from public.membres_table moi
      where moi.table_id = membres_table.table_id
        and moi.profil_id = auth.uid()
    )
  );

-- Création : le créateur s'ajoute lui-même (bootstrap, voir
-- `creer_table` appelé côté service), ou un admin actif invite un autre
-- profil. Un utilisateur ne peut jamais s'ajouter lui-même à une Table
-- dont il n'est pas le créateur.
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
    or exists (
      select 1 from public.membres_table admin
      where admin.table_id = membres_table.table_id
        and admin.profil_id = auth.uid()
        and admin.statut = 'active'
        and admin.est_admin
    )
  );

-- Modification : accepter/refuser sa propre invitation, quitter
-- soi-même, ou un admin qui retire un autre membre.
create policy "repondre a une invitation, quitter, ou retirer un membre"
  on public.membres_table for update
  to authenticated
  using (
    profil_id = auth.uid()
    or exists (
      select 1 from public.membres_table admin
      where admin.table_id = membres_table.table_id
        and admin.profil_id = auth.uid()
        and admin.statut = 'active'
        and admin.est_admin
    )
  )
  with check (
    profil_id = auth.uid()
    or exists (
      select 1 from public.membres_table admin
      where admin.table_id = membres_table.table_id
        and admin.profil_id = auth.uid()
        and admin.statut = 'active'
        and admin.est_admin
    )
  );


-- ============================================================
--  associations_experience_table — ExperienceTableAssociation
--  (règle 45-47) : many-to-many, une expérience peut vivre dans
--  plusieurs Tables sans duplication (règle 46, 86).
-- ============================================================
--  Le point d'écriture complet (depuis la publication) est le Bloc 5 —
--  ici seulement la relation et sa policy, pour que "Notre histoire"
--  puisse déjà lire ce qui y sera associé.
-- ============================================================

create table public.associations_experience_table (
  souvenir_id uuid not null references public.souvenirs (id) on delete cascade,
  table_id uuid not null references public.tables (id) on delete cascade,
  ajoute_par uuid not null references public.profils (id) on delete set null,
  ajoute_le timestamptz not null default now(),

  primary key (souvenir_id, table_id)
);

grant select, insert, delete on public.associations_experience_table to authenticated;

alter table public.associations_experience_table enable row level security;

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
  );

-- Seul l'auteur de l'expérience, membre actif de la Table visée, peut
-- l'y associer — jamais quelqu'un d'autre au nom de l'auteur.
create policy "associer sa propre experience a une table"
  on public.associations_experience_table for insert
  to authenticated
  with check (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenir_id and s.auteur_id = auth.uid()
    )
    and exists (
      select 1 from public.membres_table m
      where m.table_id = associations_experience_table.table_id
        and m.profil_id = auth.uid()
        and m.statut = 'active'
    )
  );

-- Retirer l'association : l'auteur de l'expérience, ou un admin de la
-- Table (règle 47 : ça ne supprime jamais l'expérience elle-même).
create policy "retirer une association"
  on public.associations_experience_table for delete
  to authenticated
  using (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenir_id and s.auteur_id = auth.uid()
    )
    or exists (
      select 1 from public.membres_table admin
      where admin.table_id = associations_experience_table.table_id
        and admin.profil_id = auth.uid()
        and admin.statut = 'active'
        and admin.est_admin
    )
  );


-- ============================================================
--  table_propositions — TableProposal (règle 25-32, 48)
-- ============================================================
--  Une proposition appartient à UNE seule Table (règle 29) : même
--  restaurant proposé à deux Tables = deux lignes distinctes. Un index
--  unique partiel empêche un doublon actif dans la même Table
--  (règle 30, 101) au niveau base, en plus de la vérification
--  applicative qui affiche le message "déjà proposé".
-- ============================================================

create table public.table_propositions (
  id uuid primary key default gen_random_uuid(),
  table_id uuid not null references public.tables (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete restrict,
  cree_par uuid not null references public.profils (id) on delete set null,

  etat text not null default 'active'
    check (
      etat in (
        'active', 'polling', 'date_selection', 'confirmed', 'completed',
        'declined', 'cancelled', 'expired'
      )
    ),

  cree_le timestamptz not null default now(),
  maj_le timestamptz not null default now()
);

grant select, insert, update on public.table_propositions to authenticated;

alter table public.table_propositions enable row level security;

-- "Non dupliqué" ne s'applique qu'aux états considérés actifs par le
-- produit — une fois déclinée/annulée/expirée, une nouvelle proposition
-- pour le même restaurant redevient possible (règle 30, dernière phrase).
create unique index table_propositions_actif_unique
  on public.table_propositions (table_id, restaurant_id)
  where (etat in ('active', 'polling', 'date_selection', 'confirmed'));

create policy "lire les propositions de ses tables"
  on public.table_propositions for select
  to authenticated
  using (
    exists (
      select 1 from public.membres_table m
      where m.table_id = table_propositions.table_id
        and m.profil_id = auth.uid()
        and m.statut = 'active'
    )
  );

-- Tout membre actif peut proposer (règle 28 : pas réservé aux admins
-- sans raison).
create policy "proposer un restaurant"
  on public.table_propositions for insert
  to authenticated
  with check (
    cree_par = auth.uid()
    and exists (
      select 1 from public.membres_table m
      where m.table_id = table_propositions.table_id
        and m.profil_id = auth.uid()
        and m.statut = 'active'
    )
  );

-- Annuler : le créateur de la proposition uniquement (le reste du
-- lifecycle — polling/date_selection/confirmed/completed — est du
-- ressort du Bloc 4, pas construit ici).
create policy "annuler sa propre proposition"
  on public.table_propositions for update
  to authenticated
  using (cree_par = auth.uid())
  with check (cree_par = auth.uid());


-- ============================================================
--  interets_proposition — GO / Je passe (règle 26-27)
-- ============================================================
--  V1 : deux valeurs seulement, pas de "Peut-être" (règle 27). La
--  disponibilité réelle par dates est un point de raccord Bloc 4.
-- ============================================================

create table public.interets_proposition (
  proposition_id uuid not null references public.table_propositions (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,
  interet text not null check (interet in ('go', 'passe')),
  maj_le timestamptz not null default now(),

  primary key (proposition_id, profil_id)
);

grant select, insert, update on public.interets_proposition to authenticated;

alter table public.interets_proposition enable row level security;

create policy "lire les interets des propositions de ses tables"
  on public.interets_proposition for select
  to authenticated
  using (
    exists (
      select 1 from public.table_propositions p
      join public.membres_table m
        on m.table_id = p.table_id and m.profil_id = auth.uid() and m.statut = 'active'
      where p.id = interets_proposition.proposition_id
    )
  );

create policy "repondre go ou je passe"
  on public.interets_proposition for insert
  to authenticated
  with check (
    profil_id = auth.uid()
    and exists (
      select 1 from public.table_propositions p
      join public.membres_table m
        on m.table_id = p.table_id and m.profil_id = auth.uid() and m.statut = 'active'
      where p.id = interets_proposition.proposition_id
    )
  );

create policy "changer sa reponse"
  on public.interets_proposition for update
  to authenticated
  using (profil_id = auth.uid())
  with check (profil_id = auth.uid());


-- ============================================================
--  "Notre histoire" : lecture inter-cercle explicitement autorisée
-- ============================================================
--  Problème : la policy de lecture de `souvenirs` (migration
--  `20260823000000...`) n'autorise que l'auteur ou son cercle direct
--  (abonnement accepté). Un membre d'une même Table n'est pas forcément
--  dans mon cercle — être à la même Table ne crée aucune relation
--  d'abonnement. Sans ça, "Notre histoire" resterait vide pour toute
--  expérience associée par un membre que je ne suis pas.
--
--  C'est précisément la distinction que le megaprompt annonce pour le
--  Bloc 5 ("AUDIENCE ≠ TABLE ASSOCIATION" — une association Table est
--  aussi un grant de visibilité). Le Bloc 5 centralisera ça proprement
--  (`canViewExperience`) ; en attendant, cette fonction ouvre un chemin
--  de lecture étroit et explicitement vérifié (même précédent que
--  `abonnement_accepte` / `comptes_reseau_etendu`) plutôt que de toucher
--  à la policy `souvenirs` elle-même (hors périmètre Bloc 3).
-- ============================================================

create or replace function public.experiences_table(p_table_id uuid)
returns table (
  souvenir_id uuid,
  photo_url text,
  restaurant_nom text,
  ville text,
  date_visite date,
  auteur_pseudo text,
  emotion text
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.photo_url, r.nom, r.ville, s.date_visite, pr.pseudo, s.emotion
  from public.associations_experience_table a
  join public.souvenirs s on s.id = a.souvenir_id
  join public.restaurants r on r.id = s.restaurant_id
  join public.profils pr on pr.id = s.auteur_id
  where a.table_id = p_table_id
    and s.statut = 'publie'
    and exists (
      select 1 from public.membres_table m
      where m.table_id = p_table_id
        and m.profil_id = auth.uid()
        and m.statut = 'active'
    )
  order by s.date_visite desc, s.cree_le desc;
$$;

grant execute on function public.experiences_table(uuid) to authenticated;


-- ============================================================
--  Storage : même élargissement pour les fichiers eux-mêmes
-- ============================================================
--  `experiences_table()` élargit qui peut lire la LIGNE `souvenirs`,
--  mais le bucket Storage `souvenirs` (migration
--  `20260824000000_storage_souvenirs.sql`) a sa propre policy de
--  lecture, limitée à l'auteur et son cercle direct — sans élargissement
--  équivalent ici, la mosaïque ne pourrait jamais résoudre l'URL signée
--  d'une photo partagée par un membre de Table qu'on ne suit pas.
--  Même chose pour la cover manuelle d'une Table (n'importe quel membre
--  doit pouvoir la voir, pas seulement son auteur/cercle).
-- ============================================================

create policy "voir les photos des experiences partagees dans mes tables"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'souvenirs'
    and exists (
      select 1
      from public.souvenirs s
      join public.associations_experience_table a on a.souvenir_id = s.id
      join public.membres_table m
        on m.table_id = a.table_id and m.profil_id = auth.uid() and m.statut = 'active'
      where s.photo_url = storage.objects.name and s.statut = 'publie'
    )
  );

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
      where t.couverture_photo_url = storage.objects.name
    )
  );
