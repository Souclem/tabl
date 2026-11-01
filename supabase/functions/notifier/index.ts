// Envoie les notifications du téléphone (écran verrouillé) : une demande
// de suivi, un nouvel abonné, un suivi accepté, un j'aime, un
// commentaire, une réponse à un commentaire, un j'aime sur un
// commentaire, une demande d'avis, une réponse à cette demande.
//
// L'app l'appelle juste après l'action (comme `transmettre-retours`),
// sans faire attendre l'utilisateur. La fonction ne la croit pas sur
// parole : elle relit l'action en base, faite par celui qui appelle, et
// en tire elle-même le destinataire et le texte — personne ne peut faire
// envoyer un texte inventé à quelqu'un. Une action ne notifie qu'une fois
// (table `notifications_envoyees`), et seulement dans les minutes qui
// suivent.
//
// Secrets (`supabase secrets set`, jamais dans le dépôt) :
//   APNS_CLE_ID      identifiant de la clé APNs (10 caractères)
//   APNS_EQUIPE_ID   identifiant de l'équipe Apple (10 caractères)
//   APNS_CLE_PRIVEE  contenu du fichier AuthKey_XXXXXXXXXX.p8
//   APNS_BUNDLE_ID   identifiant de l'app (be.tabl.app)

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";
import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

/** Au-delà, l'action est trop ancienne pour être notifiée. */
const RECENTE_MS = 10 * 60 * 1000;

/** Les réponses à une demande d'avis, comme dans l'app (`ReponseAvis`). */
const REPONSES: Record<string, string> = {
  oui: "😍 Oui, vas-y",
  depend: "🤔 Ça dépend",
  non: "😕 Je ne conseille pas",
};

type Evenement = {
  evenement?: string;
  cible?: string;
  souvenir?: string;
  commentaire?: string;
  demandes?: string[];
  demande?: string;
};

/** Une notification à envoyer à une personne. */
type Envoi = {
  /** Ce qui la rend unique : jamais deux fois la même. */
  cle: string;
  destinataire: string;
  /** Comme dans `mes_notifications()` : « demande_suivi »… */
  type: string;
  texte: string;
};

type Appareil = { jeton: string; environnement: string | null };

Deno.serve(async (requete) => {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const jwt = (requete.headers.get("Authorization") ?? "").replace(/^Bearer /i, "");
  const { data: { user } } = await admin.auth.getUser(jwt);
  if (!user) return Response.json({ erreur: "non connecté" }, { status: 401 });

  const corps: Evenement | null = await requete.json().catch(() => null);
  if (!corps?.evenement) {
    return Response.json({ erreur: "événement manquant" }, { status: 400 });
  }

  let envois: Envoi[];
  try {
    envois = await lire(admin, user.id, corps);
  } catch (e) {
    console.error(`notifier ${corps.evenement} :`, message(e));
    return Response.json({ erreur: message(e) }, { status: 500 });
  }

  let envoyees = 0;
  const erreurs: string[] = [];
  for (const envoi of envois) {
    // Réservée avant l'envoi : deux appels simultanés n'envoient jamais
    // la même deux fois.
    const { error: deja } = await admin
      .from("notifications_envoyees")
      .insert({ cle: envoi.cle });
    if (deja) {
      if (deja.code !== "23505") erreurs.push(`${envoi.cle} : ${deja.message}`);
      continue;
    }
    const { data: appareils, error } = await admin
      .from("appareils")
      .select("jeton, environnement")
      .eq("profil_id", envoi.destinataire)
      .returns<Appareil[]>();
    if (error) {
      erreurs.push(`${envoi.cle} : ${error.message}`);
      continue;
    }
    for (const appareil of appareils) {
      try {
        if (await pousser(admin, appareil, envoi)) envoyees++;
      } catch (e) {
        console.error(`notifier ${envoi.cle} :`, message(e));
        erreurs.push(`${envoi.cle} : ${message(e)}`);
      }
    }
  }
  return Response.json(
    { envoyees, erreurs },
    { status: erreurs.length > 0 ? 500 : 200 },
  );
});

/**
 * L'action, relue en base : faite par [moi], récente, et ce qu'il faut
 * en dire à qui. Rien si elle n'existe pas (ou plus), ou si elle me
 * concerne seul.
 */
async function lire(
  admin: SupabaseClient,
  moi: string,
  e: Evenement,
): Promise<Envoi[]> {
  const pseudo = await pseudoDe(admin, moi);
  switch (e.evenement) {
    // J'ai demandé à suivre, ou je suis (profil public).
    case "suivi": {
      if (!e.cible) return [];
      const a = await une(
        admin
          .from("abonnements")
          .select("statut, cree_le")
          .eq("suiveur_id", moi)
          .eq("suivi_id", e.cible)
          .maybeSingle(),
      );
      if (!a || !recente(a.cree_le)) return [];
      const enAttente = a.statut === "en_attente";
      return [{
        cle: `suivi:${moi}:${e.cible}:${a.cree_le}`,
        destinataire: e.cible,
        type: enAttente ? "demande_suivi" : "nouvel_abonne",
        texte: enAttente
          ? `${pseudo} souhaite vous suivre.`
          : `${pseudo} vous suit désormais.`,
      }];
    }
    // J'ai accepté la demande de [cible].
    case "suivi_accepte": {
      if (!e.cible) return [];
      const a = await une(
        admin
          .from("abonnements")
          .select("cree_le, accepte_le")
          .eq("suiveur_id", e.cible)
          .eq("suivi_id", moi)
          .eq("statut", "accepte")
          .maybeSingle(),
      );
      if (!a?.accepte_le || !recente(a.accepte_le)) return [];
      return [{
        cle: `suivi_accepte:${e.cible}:${moi}:${a.cree_le}`,
        destinataire: e.cible,
        type: "suivi_accepte",
        texte: `${pseudo} a accepté votre demande de suivi.`,
      }];
    }
    // J'ai aimé un moment.
    case "reaction": {
      if (!e.souvenir) return [];
      const r = await une(
        admin
          .from("reactions")
          .select("cree_le, souvenirs(auteur_id, restaurants(nom))")
          .eq("souvenir_id", e.souvenir)
          .eq("profil_id", moi)
          .maybeSingle(),
      );
      const souvenir = r?.souvenirs;
      if (!r || !recente(r.cree_le) || !souvenir) return [];
      if (souvenir.auteur_id === moi) return [];
      return [{
        // Sans la date : un j'aime retiré puis remis ne renvoie rien.
        cle: `reaction:${e.souvenir}:${moi}`,
        destinataire: souvenir.auteur_id,
        type: "reaction",
        texte: `${pseudo} a aimé votre moment${chez(souvenir.restaurants?.nom)}.`,
      }];
    }
    // J'ai commenté un moment, ou répondu à un commentaire. L'auteur du
    // commentaire auquel je réponds l'apprend en « réponse » ; l'auteur
    // du moment, en « commentaire » — une seule fois s'il est les deux.
    case "commentaire": {
      if (!e.commentaire) return [];
      const c = await une(
        admin
          .from("commentaires")
          .select(
            "texte, cree_le, parent_id, souvenirs(auteur_id, restaurants(nom))",
          )
          .eq("id", e.commentaire)
          .eq("auteur_id", moi)
          .maybeSingle(),
      );
      const souvenir = c?.souvenirs;
      if (!c || !recente(c.cree_le) || !souvenir) return [];
      const parent = c.parent_id
        ? await une(
          admin
            .from("commentaires")
            .select("auteur_id")
            .eq("id", c.parent_id)
            .maybeSingle(),
        )
        : null;
      const envois: Envoi[] = [];
      if (parent && parent.auteur_id !== moi) {
        envois.push({
          cle: `reponse:${e.commentaire}`,
          destinataire: parent.auteur_id,
          type: "reponse",
          texte: `${pseudo} a répondu à votre commentaire : « ${court(c.texte)} »`,
        });
      }
      if (souvenir.auteur_id !== moi && souvenir.auteur_id !== parent?.auteur_id) {
        envois.push({
          cle: `commentaire:${e.commentaire}`,
          destinataire: souvenir.auteur_id,
          type: "commentaire",
          texte: `${pseudo} a commenté votre moment${chez(souvenir.restaurants?.nom)}` +
            ` : « ${court(c.texte)} »`,
        });
      }
      return envois;
    }
    // J'ai aimé un commentaire.
    case "reaction_commentaire": {
      if (!e.commentaire) return [];
      const r = await une(
        admin
          .from("commentaires_reactions")
          .select("cree_le, commentaires(auteur_id, texte)")
          .eq("commentaire_id", e.commentaire)
          .eq("profil_id", moi)
          .maybeSingle(),
      );
      const commentaire = r?.commentaires;
      if (!r || !recente(r.cree_le) || !commentaire) return [];
      if (commentaire.auteur_id === moi) return [];
      return [{
        // Sans la date : un j'aime retiré puis remis ne renvoie rien.
        cle: `reaction_commentaire:${e.commentaire}:${moi}`,
        destinataire: commentaire.auteur_id,
        type: "reaction_commentaire",
        texte: `${pseudo} a aimé votre commentaire : « ${court(commentaire.texte)} »`,
      }];
    }
    // J'ai demandé un avis à un ou plusieurs proches.
    case "demande_avis": {
      const ids = (e.demandes ?? []).slice(0, 50);
      if (ids.length === 0) return [];
      const { data, error } = await admin
        .from("demandes_avis")
        .select("id, destinataire_id, message, cree_le, restaurants(nom)")
        .in("id", ids)
        .eq("demandeur_id", moi)
        .is("reponse", null);
      if (error) throw error;
      // deno-lint-ignore no-explicit-any
      return (data as any[])
        .filter((d) => recente(d.cree_le))
        .map((d) => ({
          cle: `demande_avis:${d.id}`,
          destinataire: d.destinataire_id,
          type: "demande_avis",
          texte: `${pseudo} vous demande votre avis${chez(d.restaurants?.nom)}` +
            ` : « ${court(d.message)} »`,
        }));
    }
    // J'ai répondu à une demande d'avis.
    case "avis_recu": {
      if (!e.demande) return [];
      const d = await une(
        admin
          .from("demandes_avis")
          .select("demandeur_id, reponse, mot, repondu_le, restaurants(nom)")
          .eq("id", e.demande)
          .eq("destinataire_id", moi)
          .not("reponse", "is", null)
          .maybeSingle(),
      );
      if (!d?.repondu_le || !recente(d.repondu_le)) return [];
      const mot = d.mot?.trim();
      return [{
        cle: `avis_recu:${e.demande}`,
        destinataire: d.demandeur_id,
        type: "avis_recu",
        texte: `${pseudo} a répondu${chez(d.restaurants?.nom)} : ` +
          `${REPONSES[d.reponse] ?? "Réponse"}` +
          (mot ? ` — « ${court(mot)} »` : ""),
      }];
    }
    default:
      return [];
  }
}

/**
 * Envoie [envoi] à un téléphone. Un jeton d'une app installée depuis
 * Xcode ne vaut que pour le « bac à sable » d'APNs, celui de TestFlight
 * et de l'App Store que pour la production : on essaie celui qu'on
 * connaît, puis l'autre, et on retient le bon. Un jeton qui ne vaut plus
 * (app supprimée) est oublié.
 */
async function pousser(
  admin: SupabaseClient,
  appareil: Appareil,
  envoi: Envoi,
): Promise<boolean> {
  const premier = appareil.environnement ?? "production";
  const second = premier === "production" ? "sandbox" : "production";
  for (const environnement of [premier, second]) {
    const resultat = await apns(environnement, appareil.jeton, envoi);
    if (resultat === "envoyee") {
      if (environnement !== appareil.environnement) {
        await admin
          .from("appareils")
          .update({ environnement })
          .eq("jeton", appareil.jeton);
      }
      return true;
    }
    if (resultat === "perime") break;
    // "ailleurs" : le jeton est d'un autre environnement, on essaie l'autre.
  }
  await admin.from("appareils").delete().eq("jeton", appareil.jeton);
  return false;
}

async function apns(
  environnement: string,
  jeton: string,
  envoi: Envoi,
): Promise<"envoyee" | "ailleurs" | "perime"> {
  const hote = environnement === "sandbox"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
  const reponse = await fetch(`https://${hote}/3/device/${jeton}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await jetonFournisseur()}`,
      "apns-topic": Deno.env.get("APNS_BUNDLE_ID") ?? "be.tabl.app",
      "apns-push-type": "alert",
      "apns-priority": "10",
    },
    body: JSON.stringify({
      aps: {
        alert: { body: envoi.texte },
        sound: "default",
        // Les notifications d'un même type se rangent ensemble.
        "thread-id": envoi.type,
      },
      type: envoi.type,
    }),
  });
  if (reponse.ok) return "envoyee";
  const raison = (await reponse.json().catch(() => null))?.reason ?? "";
  if (reponse.status === 400 && raison === "BadDeviceToken") return "ailleurs";
  if (reponse.status === 410 || raison === "Unregistered") return "perime";
  throw new Error(`APNs ${environnement} ${reponse.status} ${raison}`);
}

/**
 * Le jeton qui prouve à APNs que l'envoi vient de nous. APNs refuse
 * qu'il change plus d'une fois toutes les 20 minutes et l'exige de moins
 * d'une heure : le même sert 40 minutes, daté du début de sa période.
 */
let jetonEnCours: { valeur: string; periode: number } | null = null;

async function jetonFournisseur(): Promise<string> {
  const maintenant = Math.floor(Date.now() / 1000);
  const periode = maintenant - (maintenant % 2400);
  if (jetonEnCours?.periode === periode) return jetonEnCours.valeur;
  const idCle = Deno.env.get("APNS_CLE_ID");
  const equipe = Deno.env.get("APNS_EQUIPE_ID");
  const clePrivee = Deno.env.get("APNS_CLE_PRIVEE");
  if (!idCle || !equipe || !clePrivee) throw new Error("APNs non configuré");
  const cle = await importPKCS8(clePrivee.replace(/\\n/g, "\n"), "ES256");
  const valeur = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: idCle })
    .setIssuer(equipe)
    .setIssuedAt(periode)
    .sign(cle);
  jetonEnCours = { valeur, periode };
  return valeur;
}

async function pseudoDe(admin: SupabaseClient, id: string): Promise<string> {
  const p = await une(
    admin.from("profils").select("pseudo").eq("id", id).maybeSingle(),
  );
  return p?.pseudo ?? "Quelqu'un";
}

/** Le résultat d'une requête à une ligne, ou l'erreur levée. */
// deno-lint-ignore no-explicit-any
async function une(requete: PromiseLike<{ data: any; error: any }>) {
  const { data, error } = await requete;
  if (error) throw error;
  return data;
}

function recente(date: string): boolean {
  return Date.now() - new Date(date).getTime() < RECENTE_MS;
}

/** " chez Osteria Bella", ou rien sans restaurant. */
function chez(nom?: string | null): string {
  return nom ? ` chez ${nom}` : "";
}

/** Un texte assez court pour une notification. */
function court(texte: string): string {
  const t = texte.trim();
  return t.length > 120 ? `${t.slice(0, 119)}…` : t;
}

function message(e: unknown): string {
  return e instanceof Error ? e.message : JSON.stringify(e);
}
