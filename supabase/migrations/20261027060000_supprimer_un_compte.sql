-- ============================================================
--  Supprimer son compte
-- ============================================================
--  La fonction Edge `supprimer-compte` supprime le compte de celui qui
--  l'appelle (`auth.users`) ; la base supprime le reste en cascade
--  depuis `profils`. Deux choses l'en empêchaient.
--
--  1. Cinq colonnes « créé par » étaient à la fois `not null` et
--     `on delete set null` : supprimer quelqu'un qui avait créé une
--     Table, une proposition, confirmé une date, associé un moment ou
--     écrit dans un mini-chat échouait (« null value violates not-null
--     constraint »). L'intention était bien de garder ces lignes, sans
--     auteur : la Table vit pour ses autres membres, et ses admins
--     prennent le relais (voir 20260918010000). On retire le `not null`.
--
--  2. La fonction a besoin de lire et supprimer les souvenirs et les
--     lieux personnels de la personne avant son compte : un lieu
--     personnel ne peut pas rester sans auteur (contrainte
--     `lieu_personnel_sans_adresse`), et les souvenirs qui y ont eu lieu
--     le retiennent (`on delete restrict`). Les nouvelles tables ne sont
--     plus exposées d'office : droits explicites, au plus juste.
-- ============================================================

alter table public.tables
  alter column cree_par drop not null;

alter table public.associations_experience_table
  alter column ajoute_par drop not null;

alter table public.table_propositions
  alter column cree_par drop not null;

alter table public.confirmations_proposition
  alter column confirme_par drop not null;

alter table public.messages_organisation
  alter column auteur_id drop not null;

grant select (id, auteur_id), delete on public.souvenirs to service_role;
grant select (id, cree_par, prive), delete on public.restaurants to service_role;
