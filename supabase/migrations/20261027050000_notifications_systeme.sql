-- ============================================================
--  Notifications du téléphone (écran verrouillé)
-- ============================================================
--  Demandé le 2026-10-27, une fois le compte Apple Developer pris. La
--  cloche du Feed lit déjà les événements là où ils sont écrits
--  (`mes_notifications()`) ; ici, de quoi les pousser aussi jusqu'au
--  téléphone :
--
--  - `appareils` : les téléphones de chaque compte, par leur jeton
--    APNs. Un jeton appartient à un téléphone : s'y connecter avec un
--    autre compte le lui fait reprendre (`enregistrer_appareil`). La
--    déconnexion le retire.
--  - `notifications_envoyees` : ce qui est déjà parti, pour qu'une même
--    action ne notifie qu'une fois (un j'aime retiré puis remis ne
--    renvoie rien). Réservée à la fonction `notifier` (service role).
--
--  L'envoi lui-même vit dans `supabase/functions/notifier` : l'app
--  l'appelle juste après l'action, la fonction relit l'action en base
--  et en tire le destinataire et le texte.
-- ============================================================

create table public.appareils (
  jeton text primary key check (char_length(jeton) between 16 and 4096),
  profil_id uuid not null references public.profils (id) on delete cascade,
  plateforme text not null check (plateforme in ('ios', 'android')),
  -- 'sandbox' pour une app installée depuis Xcode, 'production' pour
  -- TestFlight et l'App Store ; appris au premier envoi.
  environnement text check (environnement in ('sandbox', 'production')),
  cree_le timestamptz not null default now(),
  vu_le timestamptz not null default now()
);

create index appareils_profil on public.appareils (profil_id);

alter table public.appareils enable row level security;

-- Rien d'autre que lire et retirer les siens : l'enregistrement passe
-- par `enregistrer_appareil`.
revoke all on public.appareils from anon, authenticated;
grant select, delete on public.appareils to authenticated;

create policy "voir ses appareils"
  on public.appareils for select
  to authenticated
  using (auth.uid() = profil_id);

create policy "retirer ses appareils"
  on public.appareils for delete
  to authenticated
  using (auth.uid() = profil_id);

-- Enregistrer ce téléphone pour moi. Le jeton peut appartenir à un
-- compte qui s'y était connecté avant : il change de main (une simple
-- policy d'update ne le permettrait pas, la ligne n'étant pas à moi).
create function public.enregistrer_appareil(p_jeton text, p_plateforme text)
returns void
language sql
volatile
security definer
set search_path = public
as $$
  insert into public.appareils (jeton, profil_id, plateforme)
  select p_jeton, auth.uid(), p_plateforme
  where auth.uid() is not null
  on conflict (jeton) do update
    set profil_id = excluded.profil_id,
        plateforme = excluded.plateforme,
        vu_le = now();
$$;

revoke execute on function public.enregistrer_appareil(text, text)
  from public, anon;
grant execute on function public.enregistrer_appareil(text, text)
  to authenticated;

create table public.notifications_envoyees (
  cle text primary key,
  envoyee_le timestamptz not null default now()
);

-- Aucun accès pour l'app : seule la fonction `notifier` (service role)
-- y lit et y écrit.
alter table public.notifications_envoyees enable row level security;
revoke all on public.notifications_envoyees from anon, authenticated;
