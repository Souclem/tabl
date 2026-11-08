// Supprime le compte de celui qui appelle, et tout ce qui est à lui.
//
// Supprimer un compte (`auth.users`) demande la clé de service : l'app
// ne peut pas le faire elle-même. La fonction ne supprime jamais que le
// compte lu dans le jeton de l'appel — personne ne peut supprimer celui
// d'un autre.
//
// La base fait presque tout : supprimer le compte supprime son profil,
// et avec lui (on delete cascade) ses souvenirs, abonnés, abonnements,
// réactions, commentaires, places dans les Tables… Ce qu'elle ne fait
// pas, la fonction le fait d'abord :
//  - les lieux personnels, qui ne peuvent pas rester sans auteur : les
//    souvenirs qui y ont eu lieu les retiennent, donc les souvenirs
//    d'abord, puis les lieux ;
//  - les photos et vidéos (souvenirs, instants, photo de profil),
//    rangées dans un dossier à son id, que la base ne connaît pas.
// Les messages d'« Aide et contact » restent, sans auteur
// (`retours.auteur_id … on delete set null`).
//
// Chaque étape peut être rejouée : si l'une échoue, l'app le dit, et un
// nouvel essai reprend là où la suppression s'était arrêtée.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";

/** Les buckets où chacun range ses fichiers dans un dossier à son id. */
const BUCKETS = ["souvenirs", "instants", "avatars"];

/** Le plus que le stockage liste ou supprime en une fois. */
const PAR_LOT = 1000;

Deno.serve(async (requete) => {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const jwt = (requete.headers.get("Authorization") ?? "").replace(/^Bearer /i, "");
  const { data: { user } } = await admin.auth.getUser(jwt);
  if (!user) return Response.json({ erreur: "non connecté" }, { status: 401 });

  try {
    await supprimer(admin, user.id);
  } catch (e) {
    const texte = e instanceof Error ? e.message : JSON.stringify(e);
    console.error(`supprimer-compte ${user.id} :`, texte);
    return Response.json({ erreur: texte }, { status: 500 });
  }
  return Response.json({ supprime: true });
});

async function supprimer(admin: SupabaseClient, id: string) {
  const { data: lieux, error: erreurLieux } = await admin
    .from("restaurants")
    .select("id")
    .eq("cree_par", id)
    .eq("prive", true);
  if (erreurLieux) throw erreurLieux;

  const { error: erreurSouvenirs } = await admin
    .from("souvenirs")
    .delete()
    .eq("auteur_id", id);
  if (erreurSouvenirs) throw erreurSouvenirs;

  if (lieux.length > 0) {
    const { error } = await admin
      .from("restaurants")
      .delete()
      .in("id", lieux.map((l) => l.id));
    if (error) throw error;
  }

  for (const bucket of BUCKETS) {
    const chemins = await fichiersDe(admin, bucket, id);
    for (let i = 0; i < chemins.length; i += PAR_LOT) {
      const { error } = await admin.storage
        .from(bucket)
        .remove(chemins.slice(i, i + PAR_LOT));
      if (error) throw error;
    }
  }

  const { error } = await admin.auth.admin.deleteUser(id);
  if (error) throw error;
}

/** Tous les fichiers d'un dossier, sous-dossiers compris (`id/mini/…`). */
async function fichiersDe(
  admin: SupabaseClient,
  bucket: string,
  dossier: string,
): Promise<string[]> {
  const chemins: string[] = [];
  for (let page = 0;; page++) {
    const { data, error } = await admin.storage
      .from(bucket)
      .list(dossier, { limit: PAR_LOT, offset: page * PAR_LOT });
    if (error) throw error;
    for (const entree of data) {
      const chemin = `${dossier}/${entree.name}`;
      // Un sous-dossier n'a pas d'id : on y descend.
      if (entree.id === null) {
        chemins.push(...await fichiersDe(admin, bucket, chemin));
      } else {
        chemins.push(chemin);
      }
    }
    if (data.length < PAR_LOT) return chemins;
  }
}
