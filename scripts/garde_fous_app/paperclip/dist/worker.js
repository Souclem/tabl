// Côté serveur du plugin : lit les réglages et ouvre l'app Mac.
// Les identifiants doivent rester ceux de GARDE_FOUS dans
// .claude/hooks/garde_fou_agents.py.
import { definePlugin, runWorker } from "@paperclipai/plugin-sdk";
import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
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

/** Le compte que les agents utilisent (le compte par défaut de Paperclip) et ceux épuisés. */
async function compte() {
  const reglages = await lireJson(COMPTES);
  if (!reglages || !Array.isArray(reglages.ordre)) return { installe: false };
  const bascule = (await lireJson(ETAT_BASCULE)) || {};
  const numero = (id) => reglages.ordre.indexOf(id) + 1 || null;

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
  return { installe: true, actif: numero(actif), epuises, tousEpuises: bascule.tous_epuises_signale === true };
}

const plugin = definePlugin({
  async setup(ctx) {
    ctx.data.register("etat", etat);
    ctx.data.register("compte", compte);
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
