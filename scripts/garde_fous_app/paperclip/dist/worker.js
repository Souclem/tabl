// Côté serveur du plugin : lit les réglages et ouvre l'app Mac ; montre le
// compte Claude des agents ; poste le point d'avancement dans le Chat.
// Les identifiants doivent rester ceux de GARDE_FOUS dans
// .claude/hooks/garde_fou_agents.py.
import { definePlugin, runWorker } from "@paperclipai/plugin-sdk";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { readlinkSync } from "node:fs";
import { readFile, rename, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

const APP = path.join(os.homedir(), "Desktop", "Garde-fous Tabl.app");
const REGLAGES = path.join(os.homedir(), ".config", "tabl", "garde_fous.json");
const GARDE_FOUS = ["supabase", "testflight", "scripts_prod", "api_supabase", "secrets", "push_main"];

/** Absent ou illisible = tout actif, comme dans le garde-fou. */
async function etat() {
  let reglages = {};
  try {
    const lu = JSON.parse(await readFile(REGLAGES, "utf8"));
    if (lu && typeof lu === "object") reglages = lu;
  } catch {
    // fichier absent ou abîmé : tout reste actif
  }
  const actifs = GARDE_FOUS.filter((id) => reglages[id] !== false).length;
  return { actifs, total: GARDE_FOUS.length };
}

// Bascule automatique entre comptes Claude : ses réglages et son état.
const COMPTES = path.join(os.homedir(), ".config", "tabl", "comptes_claude.json");
const ETAT_BASCULE = path.join(os.homedir(), ".config", "tabl", "bascule_comptes_etat.json");

async function lireJson(chemin) {
  try {
    return JSON.parse(await readFile(chemin, "utf8"));
  } catch {
    return null;
  }
}

// Choix fait dans l'app Mac (liste « Compte des agents ») : auto, compte1, compte2, free.
const CHOIX = path.join(os.homedir(), ".config", "tabl", "choix_compte.json");
const LIBELLES_CHOIX = { auto: "Automatique", compte1: "Compte 1", compte2: "Compte 2", free: "Free Claude Code" };

/** Le compte que les agents utilisent (le compte par défaut de Paperclip), ceux
 *  épuisés, le choix du propriétaire, et les agents passés sur Free Claude Code. */
async function compte() {
  const reglages = await lireJson(COMPTES);
  if (!reglages || !Array.isArray(reglages.ordre)) return { installe: false };
  const bascule = (await lireJson(ETAT_BASCULE)) || {};
  const numero = (id) => reglages.ordre.indexOf(id) + 1 || null;
  const choix = ((await lireJson(CHOIX)) || {}).choix;
  // Détail par agent noté par la bascule à chaque passage (clé "affichage").
  const detail = (bascule.affichage || []).map((l) => ({ nom: l.nom, source: l.source, force: l.force || "" }));
  const surFree = detail.filter((l) => l.source.startsWith("Free")).map((l) => l.nom);

  let actif = null;
  try {
    const reponse = await fetch(`${reglages.api}/companies/${reglages.societe}/ai-connections`);
    const liste = await reponse.json();
    const connexions = Array.isArray(liste) ? liste : liste.connections || [];
    actif = connexions.find((c) => c.isDefault)?.id ?? null;
  } catch {
    // Paperclip injoignable : on se fie à la dernière bascule notée.
  }
  const historique = bascule.historique || [];
  if (!actif && historique.length) actif = historique[historique.length - 1].compte;

  const maintenant = Date.now();
  const epuises = Object.entries(bascule.epuise_jusqua || {})
    .filter(([, fin]) => Date.parse(fin) > maintenant)
    .map(([id, fin]) => ({ numero: numero(id), jusqua: fin }))
    .sort((a, b) => a.numero - b.numero);
  return {
    installe: true, actif: numero(actif), epuises, tousEpuises: bascule.tous_epuises_signale === true,
    choix: LIBELLES_CHOIX[choix] || LIBELLES_CHOIX.auto, surFree, detail,
  };
}

// Point d'avancement : posté dans la conversation du propriétaire avec le Chef
// de projet, au nom du Chef, toutes les 15 minutes (job « point-chef »), sans IA
// et seulement si quelque chose a changé. Un commentaire posté par un plugin au
// nom d'un agent ne réveille jamais cet agent : le point ne coûte aucun crédit.
// Réglages (hors dépôt) : ~/.config/tabl/point_chef.json {api, societe, conversation, chef}.
const POINT = path.join(os.homedir(), ".config", "tabl", "point_chef.json");
const ETAT_POINT = path.join(os.homedir(), ".config", "tabl", "point_chef_etat.json");
const PANNES_IGNOREES = new Set([
  "provider_quota", "cancelled", "issue_dependencies_blocked", "issue_terminal_status",
  "legacy_disposition_repair_suppressed",
]);

// Paperclip peut tourner en heure universelle : les heures du point suivent le
// fuseau du Mac (/etc/localtime → …/zoneinfo/Europe/Brussels).
const FUSEAU = (() => {
  try {
    return readlinkSync("/etc/localtime").split("zoneinfo/")[1] || undefined;
  } catch {
    return undefined;
  }
})();

function heure(date) {
  const jour = (d) => d.toLocaleDateString("fr-FR", { timeZone: FUSEAU });
  const options = { hour: "2-digit", minute: "2-digit", timeZone: FUSEAU };
  if (jour(date) !== jour(new Date())) Object.assign(options, { day: "2-digit", month: "2-digit" });
  return date.toLocaleString("fr-FR", options);
}

function titreTache(issue) {
  const texte = issue.title.trim();
  return `${issue.identifier} ${texte.length > 70 ? texte.slice(0, 70) + "…" : texte}`;
}

async function lireApi(base, chemin, cle) {
  const reponse = await fetch(base + chemin);
  if (!reponse.ok) throw new Error(`${chemin} : ${reponse.status}`);
  const donnees = await reponse.json();
  return Array.isArray(donnees) ? donnees : donnees[cle] || [];
}

function ligneCompte(c) {
  if (!c.installe || !c.actif) return null;
  const retours = c.epuises
    .filter((e) => e.numero !== c.actif)
    .map((e) => `le ${e.numero} revient à ${heure(new Date(e.jusqua))}`);
  const suite = retours.length ? ` (${retours.join(", ")})` : "";
  const free = c.surFree?.length ? ` · sur Free Claude Code : ${c.surFree.join(", ")}` : "";
  return (c.tousEpuises ? `Comptes Claude : tous épuisés${suite}` : `Compte Claude ${c.actif}${suite}`) + free;
}

async function composerPoint({ api, societe }, depuis) {
  const agents = new Map(
    (await lireApi(api, `/companies/${societe}/agents`, "agents")).map((a) => [a.id, a.name]),
  );
  const taches = (await lireApi(api, `/companies/${societe}/issues?limit=300`, "issues")).filter(
    (i) => !i.conversationAgentId,
  );
  const parId = new Map(taches.map((i) => [i.id, i]));
  const runs = await lireApi(api, `/companies/${societe}/heartbeat-runs?limit=100`, "runs");
  const qui = (run) => agents.get(run.agentId) || "Un agent";

  const enCours = runs
    .filter((r) => r.status === "running")
    .map((r) => {
      const tache = parId.get(r.issueId);
      return `${qui(r)} : ${tache ? titreTache(tache) : "travail hors tâche"}`;
    });
  const fini = taches
    .filter((i) => i.status === "done" && i.completedAt && new Date(i.completedAt) > depuis)
    .map(titreTache);
  const aToi = taches
    .filter((i) => i.assigneeUserId && !["done", "cancelled"].includes(i.status))
    .map((i) => `${titreTache(i)} (${i.status === "in_review" ? "à relire" : "à faire"})`);
  const bloque = taches
    .filter((i) => i.status === "blocked" && i.blockerAttention?.state === "needs_attention")
    .map(titreTache);
  const pannes = runs
    .filter(
      (r) =>
        ["failed", "timed_out"].includes(r.status) && !PANNES_IGNOREES.has(r.errorCode) &&
        r.finishedAt && new Date(r.finishedAt) > depuis,
    )
    .map((r) => {
      const tache = parId.get(r.issueId);
      let erreur = (r.error || r.errorCode || "erreur").split(/\s+/).join(" ");
      erreur = erreur.replace("ACP agent reported a terminal limit failure. ", "");
      if (erreur.length > 110) erreur = erreur.slice(0, 110) + "…";
      return `${qui(r)}${tache ? " sur " + tache.identifier : ""} : ${erreur}`;
    });
  const lCompte = ligneCompte(await compte());

  // Ce qui décide s'il y a du neuf (pas l'heure du point).
  const signature = createHash("sha256")
    .update(JSON.stringify([enCours, fini, aToi, bloque, pannes, lCompte]))
    .digest("hex");
  const sections = [
    ["En ce moment", enCours], [`Fini depuis ${heure(depuis)}`, fini], ["À toi", aToi],
    ["Bloqué", bloque], ["Problèmes", pannes],
  ];
  const corps = sections
    .filter(([, lignes]) => lignes.length)
    .map(([nom, lignes]) => `**${nom}**\n` + lignes.map((l) => `- ${l}`).join("\n"));
  if (!enCours.length) corps.unshift("Aucun agent ne travaille en ce moment.");
  if (lCompte) corps.push(`_${lCompte}_`);
  return { texte: `**Point automatique de ${heure(new Date())}**\n\n` + corps.join("\n\n"), signature };
}

/** Poste le point s'il y a du neuf. `forcer` : poste même sans changement (essai manuel). */
async function posterPoint(ctx, forcer = false) {
  const reglages = await lireJson(POINT);
  if (!reglages?.conversation || !reglages?.chef) return { poste: false, raison: "réglages absents" };
  const etatPoint = (await lireJson(ETAT_POINT)) || {};
  const maintenant = new Date();
  const depuis = etatPoint.dernierPoint ? new Date(etatPoint.dernierPoint) : new Date(maintenant - 15 * 60_000);
  const { texte, signature } = await composerPoint(reglages, depuis);
  if (!forcer && signature === etatPoint.signature) return { poste: false, raison: "rien de neuf" };
  await ctx.issues.createComment(reglages.conversation, texte, reglages.societe, { authorAgentId: reglages.chef });
  const temporaire = ETAT_POINT + ".tmp";
  await writeFile(temporaire, JSON.stringify({ dernierPoint: maintenant.toISOString(), signature }, null, 1));
  await rename(temporaire, ETAT_POINT);
  return { poste: true };
}

const plugin = definePlugin({
  async setup(ctx) {
    ctx.data.register("etat", etat);
    ctx.data.register("compte", compte);
    ctx.jobs.register("point-chef", async () => {
      await posterPoint(ctx);
    });
    ctx.actions.register("point-maintenant", async () => posterPoint(ctx, true));
    ctx.actions.register("ouvrir", async () => {
      await new Promise((ok, echec) =>
        execFile("/usr/bin/open", [APP], (erreur) => (erreur ? echec(erreur) : ok())),
      );
      return { ouvert: true };
    });
  },
  async onHealth() {
    return { status: "ok", message: "Garde-fous Tabl prêt" };
  },
});

export default plugin;
runWorker(plugin, import.meta.url);
