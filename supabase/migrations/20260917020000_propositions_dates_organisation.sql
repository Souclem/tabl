-- ============================================================
--  Propositions — dates candidates, disponibilités, confirmation,
--  mini-chat (megaprompt Bloc 4)
-- ============================================================
--  `table_propositions` et `interets_proposition` (GO/Je passe) existent
--  déjà depuis le Bloc 3 (`20260917010000_tables_groupes.sql`), avec le
--  lifecycle complet déjà dans la contrainte `etat` — ce bloc construit
--  les transitions polling → date_selection → confirmed.
--
--  Règle 64 : le sondage porte sur des JOURS, pas des timestamps — la
--  date candidate et la disponibilité n'ont pas d'heure. L'heure n'est
--  ajoutée qu'à la confirmation (règle 34).
--
--  Règle 21 : le silence n'est jamais une indisponibilité. On distingue
--  donc explicitement "n'a pas encore répondu" (aucune ligne dans
--  `disponibilites_soumises`) de "a répondu, disponible aucun jour"
--  (une ligne dans `disponibilites_soumises`, aucune dans
--  `disponibilites_proposition`).
--
--  Règle 67 : les autres membres ne voient que des agrégats (X/Y), le
--  creator seul peut inspecter qui a répondu quoi. On applique donc la
--  privacy au niveau RLS (lecture des lignes brutes réservée à son
--  propre profil ou au creator) et on expose l'agrégat via une fonction
--  `security definer`, même précédent que `experiences_table` /
--  `comptes_reseau_etendu` (Blocs 1 et 3).
-- ============================================================

-- ============================================================
--  confirmations_proposition — TableProposal.confirmed_at (règle 34-37, 63)
-- ============================================================
--  Une seule confirmation par proposition (clé = proposition_id) :
--  replanifier (règle 52) supprime la ligne avant de rouvrir un sondage,
--  ça ne devient jamais un historique de confirmations. Créée avant
--  `dates_candidates_proposition` ci-dessous car ses policies s'appuient
--  sur cette table ("tant que non confirmé").
--
--  `fuseau_horaire` : stocké explicitement au moment de la confirmation
--  (règle 63, "ne jamais utiliser aveuglément le fuseau du téléphone").
--  Faute d'un service de géocodage branché sur `restaurants` (la carte
--  n'a elle-même aucune coordonnée réelle pour l'instant — voir le
--  chantier "plomberie carte" différé après les 5 blocs), on capture ici
--  le fuseau du créateur au moment de la confirmation plutôt que de le
--  recalculer côté client à chaque affichage : imparfait tant qu'aucun
--  restaurant n'a de fuseau propre, mais conforme à l'exigence "stocké
--  explicitement, pas redérivé du téléphone du lecteur".
-- ============================================================

create table public.confirmations_proposition (
  proposition_id uuid primary key references public.table_propositions (id) on delete cascade,
  date_confirmee date not null,
  heure_confirmee time,
  fuseau_horaire text not null,

  confirme_par uuid not null references public.profils (id) on delete set null,
  confirme_le timestamptz not null default now()
);

grant select, insert, update, delete on public.confirmations_proposition to authenticated;

alter table public.confirmations_proposition enable row level security;

create policy "lire la confirmation de ses tables"
  on public.confirmations_proposition for select
  to authenticated
  using (
    exists (
      select 1 from public.table_propositions p
      join public.membres_table m
        on m.table_id = p.table_id and m.profil_id = auth.uid() and m.statut = 'active'
      where p.id = confirmations_proposition.proposition_id
    )
  );

-- Règle 29 : "le système calcule, le creator clôture humainement" — donc
-- seul un insert explicite du creator confirme, jamais un calcul serveur.
create policy "creator confirme une date"
  on public.confirmations_proposition for insert
  to authenticated
  with check (
    confirme_par = auth.uid()
    and exists (
      select 1 from public.table_propositions p
      where p.id = confirmations_proposition.proposition_id and p.cree_par = auth.uid()
    )
  );

-- Règle 35 : ajouter l'heure après coup reste une mise à jour de la même
-- ligne, pas une nouvelle confirmation.
create policy "creator ajoute ou change l'heure"
  on public.confirmations_proposition for update
  to authenticated
  using (
    exists (
      select 1 from public.table_propositions p
      where p.id = confirmations_proposition.proposition_id and p.cree_par = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.table_propositions p
      where p.id = confirmations_proposition.proposition_id and p.cree_par = auth.uid()
    )
  );

-- Règle 52 : replanifier supprime la confirmation avant de rouvrir un
-- sondage de dates.
create policy "creator retire la confirmation pour replanifier"
  on public.confirmations_proposition for delete
  to authenticated
  using (
    exists (
      select 1 from public.table_propositions p
      where p.id = confirmations_proposition.proposition_id and p.cree_par = auth.uid()
    )
  );


-- ============================================================
--  dates_candidates_proposition — jours candidats proposés par le
--  creator (règle 6-9, 31-33) : max 7 côté application (règle 7).
-- ============================================================

create table public.dates_candidates_proposition (
  id uuid primary key default gen_random_uuid(),
  proposition_id uuid not null references public.table_propositions (id) on delete cascade,
  date_locale date not null,
  cree_le timestamptz not null default now(),

  unique (proposition_id, date_locale)
);

grant select, insert, delete on public.dates_candidates_proposition to authenticated;

alter table public.dates_candidates_proposition enable row level security;

create policy "lire les dates candidates de ses tables"
  on public.dates_candidates_proposition for select
  to authenticated
  using (
    exists (
      select 1 from public.table_propositions p
      join public.membres_table m
        on m.table_id = p.table_id and m.profil_id = auth.uid() and m.statut = 'active'
      where p.id = dates_candidates_proposition.proposition_id
    )
  );

-- Règle 31 : le creator ajoute/retire des dates tant que non confirmé.
create policy "creator propose des dates tant que non confirme"
  on public.dates_candidates_proposition for insert
  to authenticated
  with check (
    exists (
      select 1 from public.table_propositions p
      where p.id = dates_candidates_proposition.proposition_id and p.cree_par = auth.uid()
    )
    and not exists (
      select 1 from public.confirmations_proposition c
      where c.proposition_id = dates_candidates_proposition.proposition_id
    )
  );

create policy "creator retire une date tant que non confirme"
  on public.dates_candidates_proposition for delete
  to authenticated
  using (
    exists (
      select 1 from public.table_propositions p
      where p.id = dates_candidates_proposition.proposition_id and p.cree_par = auth.uid()
    )
    and not exists (
      select 1 from public.confirmations_proposition c
      where c.proposition_id = dates_candidates_proposition.proposition_id
    )
  );


-- ============================================================
--  disponibilites_soumises — marque qu'un participant a répondu au
--  sondage de dates, même s'il n'a sélectionné aucun jour (règle 11, 21)
-- ============================================================

create table public.disponibilites_soumises (
  proposition_id uuid not null references public.table_propositions (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,
  soumis_le timestamptz not null default now(),

  primary key (proposition_id, profil_id)
);

grant select, insert, update on public.disponibilites_soumises to authenticated;

alter table public.disponibilites_soumises enable row level security;

-- Règle 67 : un membre ordinaire ne voit que l'agrégat (fonction
-- ci-dessous) — la ligne brute n'est lisible que par son auteur ou le
-- creator de la proposition, qui a le droit d'inspecter (règle 23).
create policy "lire sa propre reponse ou celles de ses propositions"
  on public.disponibilites_soumises for select
  to authenticated
  using (
    profil_id = auth.uid()
    or exists (
      select 1 from public.table_propositions p
      where p.id = disponibilites_soumises.proposition_id and p.cree_par = auth.uid()
    )
  );

-- Règle 4 : seuls les membres actifs ayant répondu GO participent au
-- sondage de dates.
create policy "soumettre sa reponse si go et membre actif"
  on public.disponibilites_soumises for insert
  to authenticated
  with check (
    profil_id = auth.uid()
    and exists (
      select 1 from public.interets_proposition i
      join public.table_propositions p on p.id = i.proposition_id
      join public.membres_table m
        on m.table_id = p.table_id and m.profil_id = auth.uid() and m.statut = 'active'
      where i.proposition_id = disponibilites_soumises.proposition_id
        and i.profil_id = auth.uid()
        and i.interet = 'go'
    )
  );

create policy "mettre a jour sa reponse tant que non confirme"
  on public.disponibilites_soumises for update
  to authenticated
  using (profil_id = auth.uid())
  with check (
    profil_id = auth.uid()
    and not exists (
      select 1 from public.confirmations_proposition c
      where c.proposition_id = disponibilites_soumises.proposition_id
    )
  );


-- ============================================================
--  disponibilites_proposition — un jour marqué disponible par un
--  participant (règle 10-12) : l'absence de ligne ne veut rien dire par
--  elle-même, seule `disponibilites_soumises` fait foi de "a répondu".
-- ============================================================

create table public.disponibilites_proposition (
  date_candidate_id uuid not null references public.dates_candidates_proposition (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,

  primary key (date_candidate_id, profil_id)
);

grant select, insert, delete on public.disponibilites_proposition to authenticated;

alter table public.disponibilites_proposition enable row level security;

create policy "lire sa propre disponibilite ou celles de ses propositions"
  on public.disponibilites_proposition for select
  to authenticated
  using (
    profil_id = auth.uid()
    or exists (
      select 1 from public.dates_candidates_proposition d
      join public.table_propositions p on p.id = d.proposition_id
      where d.id = disponibilites_proposition.date_candidate_id and p.cree_par = auth.uid()
    )
  );

-- Règle 12 : "modifier mes disponibilités" fonctionne par
-- suppression + réinsertion de ses propres lignes, jamais par un
-- doublon — la policy delete ci-dessous couvre cette réinsertion.
create policy "marquer sa disponibilite si go et non confirme"
  on public.disponibilites_proposition for insert
  to authenticated
  with check (
    profil_id = auth.uid()
    and not exists (
      select 1 from public.dates_candidates_proposition d
      join public.confirmations_proposition c on c.proposition_id = d.proposition_id
      where d.id = disponibilites_proposition.date_candidate_id
    )
    and exists (
      select 1 from public.dates_candidates_proposition d
      join public.interets_proposition i on i.proposition_id = d.proposition_id
      join public.table_propositions p on p.id = d.proposition_id
      join public.membres_table m
        on m.table_id = p.table_id and m.profil_id = auth.uid() and m.statut = 'active'
      where d.id = disponibilites_proposition.date_candidate_id
        and i.profil_id = auth.uid()
        and i.interet = 'go'
    )
  );

create policy "retirer sa propre disponibilite tant que non confirme"
  on public.disponibilites_proposition for delete
  to authenticated
  using (
    profil_id = auth.uid()
    and not exists (
      select 1 from public.dates_candidates_proposition d
      join public.confirmations_proposition c on c.proposition_id = d.proposition_id
      where d.id = disponibilites_proposition.date_candidate_id
    )
  );


-- ============================================================
--  peut_acceder_organisation — condition d'accès de la règle 41,
--  factorisée pour ne pas la dupliquer dans les policies select/insert
--  de `messages_organisation` ci-dessous. Définie avant la table qui
--  s'appuie sur elle (les policies sont évaluées à l'exécution, mais la
--  fonction doit déjà exister au moment où `create policy` la référence).
-- ============================================================

create or replace function public.peut_acceder_organisation(p_proposition_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1 from public.table_propositions p
    where p.id = p_proposition_id and p.cree_par = auth.uid()
  ) or exists (
    select 1 from public.interets_proposition i
    join public.table_propositions p on p.id = i.proposition_id
    join public.membres_table m
      on m.table_id = p.table_id and m.profil_id = auth.uid() and m.statut = 'active'
    where i.proposition_id = p_proposition_id
      and i.profil_id = auth.uid()
      and i.interet = 'go'
  );
$$;

grant execute on function public.peut_acceder_organisation(uuid) to authenticated;


-- ============================================================
--  messages_organisation — CoordinationThread, texte seul (règle 38-48)
-- ============================================================
--  Accès (règle 41) : le creator, plus les membres actifs ayant répondu
--  GO. Un membre qui passe de GO à "Je passe" perd l'accès — la
--  condition se réévalue à chaque lecture/écriture, il n'y a pas de
--  liste d'accès à synchroniser séparément.
-- ============================================================

create table public.messages_organisation (
  id uuid primary key default gen_random_uuid(),
  proposition_id uuid not null references public.table_propositions (id) on delete cascade,
  auteur_id uuid not null references public.profils (id) on delete set null,
  contenu text not null check (char_length(contenu) between 1 and 500),
  cree_le timestamptz not null default now()
);

grant select, insert, delete on public.messages_organisation to authenticated;

alter table public.messages_organisation enable row level security;

create policy "lire l'organisation si creator ou go actif"
  on public.messages_organisation for select
  to authenticated
  using (public.peut_acceder_organisation(proposition_id));

create policy "ecrire dans l'organisation si creator ou go actif"
  on public.messages_organisation for insert
  to authenticated
  with check (
    auteur_id = auth.uid() and public.peut_acceder_organisation(proposition_id)
  );

-- Règle 48 : l'auteur peut supprimer son propre message, rien d'autre
-- (pas d'édition).
create policy "supprimer son propre message"
  on public.messages_organisation for delete
  to authenticated
  using (auteur_id = auth.uid());


-- ============================================================
--  Fonctions déclaratives (agrégats anonymisés)
-- ============================================================
--  `peut_acceder_organisation` est définie plus haut, avant
--  `messages_organisation` qui s'appuie sur elle.
-- ============================================================

-- Règle 14-22, 67 : agrégat par date candidate, jamais l'identité de qui
-- est disponible pour un membre ordinaire (seul le creator lit les
-- lignes brutes, cf. policies plus haut).
create or replace function public.resultats_disponibilite(p_proposition_id uuid)
returns table (date_candidate_id uuid, date_locale date, disponibles integer, eligibles integer)
language sql
stable
security definer
set search_path = public
as $$
  with eligibles as (
    select i.profil_id
    from public.interets_proposition i
    join public.table_propositions p on p.id = i.proposition_id
    join public.membres_table m
      on m.table_id = p.table_id and m.profil_id = i.profil_id and m.statut = 'active'
    where i.proposition_id = p_proposition_id and i.interet = 'go'
  )
  select
    d.id,
    d.date_locale,
    (
      select count(*)::int from public.disponibilites_proposition dp
      where dp.date_candidate_id = d.id and dp.profil_id in (select profil_id from eligibles)
    ) as disponibles,
    (select count(*)::int from eligibles) as eligibles
  from public.dates_candidates_proposition d
  where d.proposition_id = p_proposition_id
  order by d.date_locale;
$$;

grant execute on function public.resultats_disponibilite(uuid) to authenticated;

-- Règle 22 : progression globale ("4/6 ont répondu"), sans exposer qui.
create or replace function public.progression_disponibilite(p_proposition_id uuid)
returns table (soumis integer, eligibles integer)
language sql
stable
security definer
set search_path = public
as $$
  with eligibles as (
    select i.profil_id
    from public.interets_proposition i
    join public.table_propositions p on p.id = i.proposition_id
    join public.membres_table m
      on m.table_id = p.table_id and m.profil_id = i.profil_id and m.statut = 'active'
    where i.proposition_id = p_proposition_id and i.interet = 'go'
  )
  select
    (
      select count(*)::int from public.disponibilites_soumises ds
      where ds.proposition_id = p_proposition_id and ds.profil_id in (select profil_id from eligibles)
    ) as soumis,
    (select count(*)::int from eligibles) as eligibles;
$$;

grant execute on function public.progression_disponibilite(uuid) to authenticated;
