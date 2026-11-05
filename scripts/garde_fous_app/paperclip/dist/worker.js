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

const plugin = definePlugin({
  async setup(ctx) {
    ctx.data.register("etat", etat);
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
