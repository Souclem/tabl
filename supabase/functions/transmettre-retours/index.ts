// Recopie les nouveaux messages d'« Aide et contact » (table `retours`)
// dans la Google Sheet de l'équipe (voir `scripts/feuille_retours.gs`).
//
// L'app l'appelle juste après chaque envoi. Elle envoie tout ce qui
// n'est pas encore parti : un message resté en route (réseau, feuille
// indisponible) part avec le suivant.
//
// Secrets (`supabase secrets set`, jamais dans le dépôt) :
//   FEUILLE_RETOURS_URL    adresse de l'application web Apps Script
//   FEUILLE_RETOURS_JETON  le même jeton que dans la feuille

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";

/** Le libellé de chaque type dans la feuille. */
const LIBELLES: Record<string, string> = {
  bug: "Bug",
  idee: "Idée",
  pas_clair: "Pas clair",
  lieu: "Lieu à corriger",
  signalement: "Signalement",
  autre: "Autre",
};

/** Messages envoyés au plus par appel : la fonction reste brève. */
const PAR_APPEL = 20;

type Retour = {
  id: string;
  type: string;
  texte: string;
  captures: string[];
  plateforme: string | null;
  systeme: string | null;
  cree_le: string;
  profils: { pseudo: string } | null;
};

Deno.serve(async () => {
  const adresse = Deno.env.get("FEUILLE_RETOURS_URL");
  const jeton = Deno.env.get("FEUILLE_RETOURS_JETON");
  if (!adresse || !jeton) {
    return Response.json({ erreur: "feuille non configurée" }, { status: 503 });
  }
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: enAttente, error } = await admin
    .from("retours")
    .select("id")
    .is("transmis_le", null)
    .order("cree_le")
    .limit(PAR_APPEL);
  if (error) return Response.json({ erreur: error.message }, { status: 500 });

  let transmis = 0;
  for (const { id } of enAttente) {
    // Réservé avant l'envoi : deux appels simultanés n'envoient jamais
    // le même message deux fois.
    const { data: retour } = await admin
      .from("retours")
      .update({ transmis_le: new Date().toISOString() })
      .eq("id", id)
      .is("transmis_le", null)
      .select(
        "id, type, texte, captures, plateforme, systeme, cree_le, profils(pseudo)",
      )
      .maybeSingle<Retour>();
    if (!retour) continue;
    try {
      await envoyer(adresse, jeton, admin, retour);
      transmis++;
    } catch (e) {
      // Pas parti : rendu à la file, le prochain appel réessaiera.
      console.error(`retour ${id} :`, e);
      await admin.from("retours").update({ transmis_le: null }).eq("id", id);
    }
  }
  return Response.json({ transmis });
});

async function envoyer(
  adresse: string,
  jeton: string,
  admin: SupabaseClient,
  retour: Retour,
) {
  const captures = [];
  for (const [i, chemin] of retour.captures.entries()) {
    // Dix minutes suffisent : la feuille la copie aussitôt dans le Drive
    // de l'équipe, aucun lien vers le bucket ne reste ouvert.
    const { data, error } = await admin.storage
      .from("retours")
      .createSignedUrl(chemin, 600);
    if (error) throw error;
    captures.push({ nom: `Capture ${i + 1}`, url: data.signedUrl });
  }

  const reponse = await fetch(adresse, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jeton,
      id: retour.id,
      recuLe: new Date(retour.cree_le).toISOString(),
      type: LIBELLES[retour.type] ?? retour.type,
      message: retour.texte,
      auteur: retour.profils?.pseudo ?? "",
      appareil: appareil(retour),
      captures,
    }),
  });
  // Apps Script répond toujours 200, même en erreur : seul `ok` compte.
  const resultat = await reponse.json().catch(() => null);
  if (!resultat?.ok) {
    throw new Error(resultat?.erreur ?? `réponse inattendue (${reponse.status})`);
  }
}

/** "iPhone · Version 18.2 (Build 22C150)". */
function appareil({ plateforme, systeme }: Retour): string {
  const nom = { ios: "iPhone", android: "Android" }[plateforme ?? ""] ??
    plateforme ?? "";
  return [nom, systeme].filter(Boolean).join(" · ");
}
