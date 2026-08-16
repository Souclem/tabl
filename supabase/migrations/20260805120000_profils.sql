-- ============================================================
--  profils — le profil public d'un utilisateur
-- ============================================================
--  Supabase gère lui-même les comptes dans `auth.users` (e-mail,
--  mot de passe chiffré, jetons). Cette table-ci ne stocke que ce
--  qui nous appartient : le pseudo, et plus tard l'avatar et la bio.
--
--  On ne touche jamais à `auth.users` directement : c'est le
--  serveur d'authentification qui l'écrit.
-- ============================================================

create table public.profils (
  -- Même identifiant que le compte : un profil = un compte.
  -- `on delete cascade` : si le compte est supprimé, le profil part avec.
  id uuid primary key references auth.users (id) on delete cascade,

  pseudo text not null,
  cree_le timestamptz not null default now(),

  -- Les mêmes règles que Validation.pseudo côté Dart. Dupliquer la règle
  -- ici n'est pas une redite inutile : le client peut être contourné,
  -- la base est le dernier rempart.
  constraint pseudo_longueur check (char_length(pseudo) between 3 and 20),
  constraint pseudo_format check (pseudo ~ '^[a-zA-Z0-9_.-]+$')
);

-- Unicité insensible à la casse : « Camille » et « camille » sont le
-- même pseudo, sinon deux personnes seraient indiscernables dans le fil.
create unique index profils_pseudo_unique on public.profils (lower(pseudo));

-- ============================================================
--  Droits d'accès
-- ============================================================
--  Le projet est configuré en « fermé par défaut » : sans les GRANT
--  ci-dessous, la table est invisible depuis l'application.
--
--  `authenticated` = quelqu'un de connecté.
--  `anon`          = visiteur non connecté. On ne lui donne rien.
--
--  Un GRANT ouvre la porte de la table ; les policies RLS décident
--  ensuite ligne par ligne. Il faut les deux.
-- ============================================================

grant select, insert, update on public.profils to authenticated;

alter table public.profils enable row level security;

-- Lecture : pour l'instant, chacun ne voit que son propre profil.
-- Quand les amitiés existeront, on ajoutera « ... ou si on est amis ».
create policy "lire son profil"
  on public.profils for select
  to authenticated
  using (auth.uid() = id);

-- Création : on ne peut créer qu'une ligne portant son propre
-- identifiant. Impossible de fabriquer un profil au nom d'un autre.
create policy "creer son profil"
  on public.profils for insert
  to authenticated
  with check (auth.uid() = id);

-- Modification : uniquement le sien.
create policy "modifier son profil"
  on public.profils for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Pas de policy DELETE : on ne supprime pas un profil à la main.
-- Supprimer le compte fait partir le profil en cascade.
