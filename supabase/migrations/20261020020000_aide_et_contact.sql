-- ============================================================
--  Aide et contact : les messages des utilisateurs à l'équipe
-- ============================================================
--  Un bug, une idée, quelque chose de pas clair… avec jusqu'à trois
--  captures d'écran. Chacun envoie les siens et ne relit que les
--  siens. L'équipe les lit dans une Google Sheet partagée, où la
--  fonction `transmettre-retours` recopie chaque nouveau message.
--  Pas de modification après coup : on en envoie un autre.
-- ============================================================

create table public.retours (
  id uuid primary key default gen_random_uuid(),
  -- Gardé si le compte est supprimé : un bug signalé reste utile.
  auteur_id uuid references public.profils (id) on delete set null,
  type text not null check (
    type in ('bug', 'idee', 'pas_clair', 'lieu', 'signalement', 'autre')
  ),
  texte text not null check (char_length(btrim(texte)) between 1 and 2000),
  -- Chemins dans le bucket `retours`, pas des URLs.
  captures text[] not null default '{}' check (cardinality(captures) <= 3),
  -- "ios" / "android", et la version du système : de quoi reproduire
  -- un bug.
  plateforme text,
  systeme text,
  -- Le suivi (statut, priorité, responsable) se fait dans la feuille de
  -- l'équipe, pas ici : un seul endroit à tenir à jour.
  cree_le timestamptz not null default now(),
  -- Recopié dans la feuille de l'équipe ; `null` : pas encore parti.
  transmis_le timestamptz
);

create index retours_recents on public.retours (cree_le desc);
create index retours_a_transmettre on public.retours (cree_le)
  where transmis_le is null;

grant select, insert on public.retours to authenticated;
-- La fonction `transmettre-retours` lit les messages et marque ceux
-- qu'elle a recopiés (les nouvelles tables ne sont plus exposées
-- d'office, pas même au rôle service).
grant select, update (transmis_le) on public.retours to service_role;
alter table public.retours enable row level security;

create policy "ecrire a l'equipe"
  on public.retours for insert
  to authenticated
  with check (auteur_id = auth.uid() and transmis_le is null);

create policy "relire ses messages a l'equipe"
  on public.retours for select
  to authenticated
  using (auteur_id = auth.uid());


-- ------------------------------------------------------------
--  Les captures d'écran : privées, chacun dépose dans son dossier
-- ------------------------------------------------------------
--  Pas de lecture pour les utilisateurs, pas même des leurs : seule
--  l'équipe les regarde.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('retours', 'retours', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "deposer ses captures pour l'equipe"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'retours'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
