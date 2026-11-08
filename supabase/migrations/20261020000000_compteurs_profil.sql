-- ============================================================
--  Compteurs d'un profil : moments, abonnés, abonnements
-- ============================================================
--  Comme Instagram : le nombre de moments, d'abonnés et d'abonnements
--  d'un profil est visible par tous, même quand le profil est privé —
--  les moments eux-mêmes et les listes (qui suit qui) restent protégés
--  par leurs policies.
--
--  Une fonction plutôt qu'une policy élargie : ouvrir la lecture de la
--  tables aux autres exposerait les listes elles-mêmes. Celle-ci ne
--  renvoie que trois nombres : moments publiés, relations acceptées
--  seulement (une demande en attente n'est pas un abonnement).
-- ============================================================

create or replace function public.compteurs_profil(p_profil uuid)
returns table (moments integer, abonnes integer, abonnements integer)
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select count(*)::integer from public.souvenirs
      where auteur_id = p_profil and statut = 'publie'),
    (select count(*)::integer from public.abonnements
      where suivi_id = p_profil and statut = 'accepte'),
    (select count(*)::integer from public.abonnements
      where suiveur_id = p_profil and statut = 'accepte');
$$;

revoke execute on function public.compteurs_profil(uuid) from public, anon;
grant execute on function public.compteurs_profil(uuid) to authenticated;
