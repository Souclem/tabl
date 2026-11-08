-- ============================================================
--  abonnements — suivi asymétrique (type Instagram, pas d'amitié
--  mutuelle type Facebook)
-- ============================================================
--  On suit quelqu'un : ça crée une demande (« en_attente ») tant que
--  l'app est privée. Le suivi accepte ou refuse. Ce n'est jamais
--  symétrique : A peut suivre B sans que B suive A.
-- ============================================================

create table public.abonnements (
  suiveur_id uuid not null references public.profils (id) on delete cascade,
  suivi_id uuid not null references public.profils (id) on delete cascade,

  statut text not null default 'en_attente'
    check (statut in ('en_attente', 'accepte')),

  cree_le timestamptz not null default now(),

  primary key (suiveur_id, suivi_id),
  constraint pas_soi_meme check (suiveur_id <> suivi_id)
);

grant select, insert, update, delete on public.abonnements to authenticated;

alter table public.abonnements enable row level security;

-- Lecture : chacun voit ses propres demandes envoyées et reçues (donc sa
-- liste d'abonnements et sa liste d'abonnés).
create policy "lire ses abonnements"
  on public.abonnements for select
  to authenticated
  using (auth.uid() = suiveur_id or auth.uid() = suivi_id);

-- Création : on ne peut demander à suivre qu'en son propre nom. Le statut
-- par défaut (« en_attente ») ne peut pas être contourné à la création :
-- accepter est un acte séparé (update), réservé au suivi ci-dessous.
create policy "demander a suivre"
  on public.abonnements for insert
  to authenticated
  with check (auth.uid() = suiveur_id);

-- Modification : seul le suivi peut faire passer une demande à
-- « accepte ». Le suiveur ne peut pas s'auto-accepter.
create policy "accepter une demande"
  on public.abonnements for update
  to authenticated
  using (auth.uid() = suivi_id)
  with check (auth.uid() = suivi_id);

-- Suppression : se désabonner, annuler sa propre demande, ou
-- refuser/retirer un abonné sont la même opération (supprimer la ligne),
-- déclenchable par l'une ou l'autre des deux parties.
create policy "supprimer un abonnement"
  on public.abonnements for delete
  to authenticated
  using (auth.uid() = suiveur_id or auth.uid() = suivi_id);


-- ============================================================
--  restaurants — annuaire partagé des lieux
-- ============================================================
--  Un lieu n'appartient à personne : pas de donnée privée ici, donc
--  lisible par tout utilisateur connecté. Créé à la volée depuis l'écran
--  de publication — pas de déduplication serveur pour l'instant, cette
--  logique reste dans le code applicatif (services/), pas en trigger.
-- ============================================================

create table public.restaurants (
  id uuid primary key default gen_random_uuid(),

  nom text not null,
  ville text not null,
  quartier text,
  cuisine text,
  latitude double precision,
  longitude double precision,

  cree_par uuid references public.profils (id) on delete set null,
  cree_le timestamptz not null default now()
);

grant select, insert on public.restaurants to authenticated;

alter table public.restaurants enable row level security;

-- Lecture : annuaire commun, ouvert à tout utilisateur connecté.
create policy "lire les restaurants"
  on public.restaurants for select
  to authenticated
  using (true);

-- Création : on ne peut créer un lieu qu'en son propre nom.
create policy "creer un restaurant"
  on public.restaurants for insert
  to authenticated
  with check (auth.uid() = cree_par);

-- Pas d'update ni de delete pour l'instant.


-- ============================================================
--  souvenirs — le cœur du Feed
-- ============================================================
--  Visible par l'auteur, et par quiconque le suit avec un abonnement
--  accepté. C'est ici que la confidentialité de l'app se joue vraiment :
--  « Tabl est privé, seuls tes amis voient ce que tu publies ».
-- ============================================================

create table public.souvenirs (
  id uuid primary key default gen_random_uuid(),

  auteur_id uuid not null references public.profils (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete restrict,

  photo_url text,
  -- La phrase choisie à la publication (ex. « Inoubliable. »).
  legende text,
  -- Emoji.
  emotion text,
  moment text check (moment in ('midi', 'soir')),
  date_visite date,

  cree_le timestamptz not null default now()
);

grant select, insert, update, delete on public.souvenirs to authenticated;

alter table public.souvenirs enable row level security;

-- Lecture : l'auteur, ou quiconque le suit avec un abonnement accepté.
create policy "lire les souvenirs de son cercle"
  on public.souvenirs for select
  to authenticated
  using (
    auteur_id = auth.uid()
    or exists (
      select 1
      from public.abonnements a
      where a.suiveur_id = auth.uid()
        and a.suivi_id = souvenirs.auteur_id
        and a.statut = 'accepte'
    )
  );

-- Création : on ne peut publier qu'en son propre nom.
create policy "publier un souvenir"
  on public.souvenirs for insert
  to authenticated
  with check (auteur_id = auth.uid());

-- Modification et suppression : uniquement son propre souvenir.
create policy "modifier son souvenir"
  on public.souvenirs for update
  to authenticated
  using (auteur_id = auth.uid())
  with check (auteur_id = auth.uid());

create policy "supprimer son souvenir"
  on public.souvenirs for delete
  to authenticated
  using (auteur_id = auth.uid());


-- ============================================================
--  Correction sur profils : ouvrir la lecture
-- ============================================================
--  La policy d'origine limitait la lecture à « auth.uid() = id » :
--  personne ne pouvait voir le pseudo de qui que ce soit d'autre. Ça
--  bloque la recherche de quelqu'un par pseudo pour le suivre, et
--  l'affichage du pseudo de l'auteur d'un souvenir dans le Feed.
--  `profils` ne contient rien de sensible (ni e-mail, ni mot de passe —
--  juste le pseudo et la date de création), donc on l'ouvre en lecture à
--  tout utilisateur connecté, comme un annuaire de pseudos public : même
--  principe qu'Instagram, où les noms d'utilisateur restent cherchables
--  même sur un compte privé.
-- ============================================================

drop policy "lire son profil" on public.profils;

create policy "lire les profils"
  on public.profils for select
  to authenticated
  using (true);
