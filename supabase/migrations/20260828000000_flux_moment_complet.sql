-- ============================================================
--  souvenirs — flux complet de création d'un moment
-- ============================================================
--  Ajoute ce qui manquait pour le parcours Capturer → Brouillon →
--  Finaliser (voir instruction/Clément (2)/scraps/clement.txt, B7-B11) :
--  un statut brouillon/publié, la visibilité choisie par l'auteur, le
--  marquage Golden Buzzer, et la boisson (texte + photo optionnelle).
--  `emotion` existait déjà (colonne libre depuis la migration initiale)
--  mais n'était pas encore utilisée côté application.
-- ============================================================

alter table public.souvenirs
  add column statut text not null default 'publie'
    check (statut in ('brouillon', 'publie')),
  add column visibilite text not null default 'cercle'
    check (visibilite in ('cercle', 'prive')),
  add column golden_buzzer boolean not null default false,
  add column boisson_texte text,
  add column boisson_photo_url text;

-- La policy de lecture d'origine ne distinguait ni le statut ni la
-- visibilité : un brouillon ou un souvenir "gardé pour moi" devenait
-- visible par le cercle dès que RLS autorisait l'auteur. On resserre :
-- seul l'auteur voit ses propres lignes quel que soit leur état ; le
-- cercle ne voit que ce qui est à la fois publié ET partagé.
drop policy "lire les souvenirs de son cercle" on public.souvenirs;
create policy "lire les souvenirs de son cercle"
  on public.souvenirs for select
  to authenticated
  using (
    auteur_id = auth.uid()
    or (
      statut = 'publie'
      and visibilite = 'cercle'
      and public.abonnement_accepte(auteur_id)
    )
  );


-- ============================================================
--  souvenirs_amis_tagues — amis présents lors d'un moment
-- ============================================================
--  Sélection multiple optionnelle à la finalisation (B9). Une ligne =
--  un ami tagué sur un moment. Visibilité alignée sur celle du souvenir
--  lui-même, comme reactions/commentaires.
-- ============================================================

create table public.souvenirs_amis_tagues (
  souvenir_id uuid not null references public.souvenirs (id) on delete cascade,
  profil_id uuid not null references public.profils (id) on delete cascade,
  primary key (souvenir_id, profil_id)
);

grant select, insert, delete on public.souvenirs_amis_tagues to authenticated;

alter table public.souvenirs_amis_tagues enable row level security;

create policy "lire les amis tagues des souvenirs visibles"
  on public.souvenirs_amis_tagues for select
  to authenticated
  using (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenirs_amis_tagues.souvenir_id
    )
  );

-- Création : uniquement par l'auteur du souvenir concerné — on ne se
-- tague pas soi-même sur le moment de quelqu'un d'autre.
create policy "taguer un ami sur son propre souvenir"
  on public.souvenirs_amis_tagues for insert
  to authenticated
  with check (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenir_id and s.auteur_id = auth.uid()
    )
  );

create policy "retirer un ami tague de son propre souvenir"
  on public.souvenirs_amis_tagues for delete
  to authenticated
  using (
    exists (
      select 1 from public.souvenirs s
      where s.id = souvenirs_amis_tagues.souvenir_id and s.auteur_id = auth.uid()
    )
  );
