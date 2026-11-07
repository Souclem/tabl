// Plugin Paperclip « Garde-fous Tabl » : deux entrées dans la barre latérale.
// - Garde-fous : ouvre l'app Mac « Garde-fous Tabl » et montre combien de
//   garde-fous sont actifs.
// - Compte Claude : le compte Claude que les agents utilisent en ce moment, posé
//   par la bascule automatique (~/.config/tabl/bascule_comptes.py, hors dépôt).
//
// Les cases se cochent dans l'app Mac, jamais dans Paperclip : en local, tout
// processus de la machine (agents compris) a les droits d'admin sur Paperclip.
// Ce plugin ne fait donc que lire l'état et ouvrir la fenêtre.
//
// Écrit en JavaScript sans étape de build (pas de TypeScript ni de JSX).

const manifest = {
  id: "tabl.garde-fous",
  apiVersion: 1,
  version: "1.1.0",
  displayName: "Garde-fous Tabl",
  description: "Ouvre l'app Garde-fous Tabl (ce que les agents ont le droit de faire) et montre le compte Claude utilisé par les agents.",
  author: "Tabl",
  categories: ["ui"],
  capabilities: ["ui.sidebar.register"],
  entrypoints: {
    worker: "./dist/worker.js",
    ui: "./dist/ui",
  },
  ui: {
    slots: [
      {
        type: "sidebar",
        id: "garde-fous-lien",
        displayName: "Garde-fous",
        exportName: "LienGardeFous",
      },
      {
        type: "sidebar",
        id: "compte-claude",
        displayName: "Compte Claude",
        exportName: "CompteClaude",
      },
    ],
  },
};

export default manifest;
