// Entrée « Garde-fous » de la barre latérale de Paperclip.
// React et le SDK sont fournis par Paperclip ; pas de JSX, donc pas de build.
import React from "react";
import { usePluginAction, usePluginData } from "@paperclipai/plugin-sdk/ui";

const h = React.createElement;

function Bouclier() {
  return h(
    "svg",
    {
      viewBox: "0 0 24 24", className: "h-4 w-4", fill: "none", stroke: "currentColor",
      strokeWidth: "1.9", strokeLinecap: "round", strokeLinejoin: "round", "aria-hidden": "true",
    },
    h("path", { d: "M12 3l7 3v5c0 4.5-3 8.2-7 10-4-1.8-7-5.5-7-10V6l7-3z" }),
    h("path", { d: "M9 12l2 2 4-4" }),
  );
}

export function LienGardeFous() {
  const etat = usePluginData("etat");
  const ouvrir = usePluginAction("ouvrir");
  const [erreur, setErreur] = React.useState(null);

  // L'état change dans l'app Mac : on le relit quand on revient sur l'onglet.
  React.useEffect(() => {
    const relire = () => etat.refresh && etat.refresh();
    window.addEventListener("focus", relire);
    return () => window.removeEventListener("focus", relire);
  }, [etat.refresh]);

  const donnees = etat.data;
  const tousActifs = donnees && donnees.actifs === donnees.total;
  const pastille = donnees ? `${donnees.actifs}/${donnees.total}` : "…";

  return h(
    "button",
    {
      type: "button",
      title: erreur || "Ouvrir les garde-fous des agents (ce qu'ils ont le droit de faire)",
      onClick: async () => {
        try {
          setErreur(null);
          await ouvrir({});
        } catch (e) {
          setErreur("Impossible d'ouvrir Garde-fous Tabl : " + (e && e.message ? e.message : e));
        }
      },
      className:
        "flex w-full items-center gap-2.5 px-3 py-2 text-[13px] font-medium transition-colors " +
        "text-foreground/80 hover:bg-accent/50 hover:text-foreground",
    },
    h("span", { className: "relative shrink-0" }, h(Bouclier)),
    h("span", { className: "flex-1 truncate text-left" }, "Garde-fous"),
    h(
      "span",
      {
        className:
          "rounded px-1.5 text-[11px] tabular-nums " +
          (erreur ? "text-red-500" : tousActifs ? "text-emerald-500" : "text-amber-500"),
      },
      erreur ? "!" : pastille,
    ),
  );
}

// Entrée « Compte Claude » : le compte que les agents utilisent en ce moment.
// Vert : compte 1 (prioritaire). Orange : compte de secours. Rouge : tous épuisés.

function Puce() {
  return h(
    "svg",
    {
      viewBox: "0 0 24 24", className: "h-4 w-4", fill: "none", stroke: "currentColor",
      strokeWidth: "1.9", strokeLinecap: "round", strokeLinejoin: "round", "aria-hidden": "true",
    },
    h("path", { d: "M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z" }),
    h("path", { d: "M19 16l.7 1.8 1.8.7-1.8.7L19 21l-.7-1.8-1.8-.7 1.8-.7z" }),
  );
}

function heure(iso) {
  const date = new Date(iso);
  const options = { hour: "2-digit", minute: "2-digit" };
  if (date.toDateString() !== new Date().toDateString()) Object.assign(options, { day: "numeric", month: "short" });
  return date.toLocaleString("fr-FR", options);
}

export function CompteClaude() {
  const compte = usePluginData("compte");

  // La bascule passe toutes les minutes : on relit au même rythme, et au retour sur l'onglet.
  React.useEffect(() => {
    const relire = () => compte.refresh && compte.refresh();
    const minuterie = setInterval(relire, 60_000);
    window.addEventListener("focus", relire);
    return () => {
      clearInterval(minuterie);
      window.removeEventListener("focus", relire);
    };
  }, [compte.refresh]);

  const donnees = compte.data;
  if (donnees && !donnees.installe) return null;

  const surFree = (donnees && donnees.surFree) || [];
  const retours = donnees
    ? donnees.epuises.filter((e) => e.numero !== donnees.actif).map((e) => `le ${e.numero} revient à ${heure(e.jusqua)}`)
    : [];
  let pastille = "…";
  let couleur = "text-muted-foreground";
  let titre = "Compte Claude utilisé par les agents";
  if (donnees && donnees.tousEpuises) {
    pastille = "—";
    couleur = "text-red-500";
    titre = "Tous les comptes Claude sont épuisés.";
  } else if (donnees && donnees.actif) {
    pastille = String(donnees.actif);
    couleur = donnees.actif === 1 ? "text-emerald-500" : "text-amber-500";
    titre = surFree.length
      ? `Les autres agents utilisent le Compte Claude ${donnees.actif}.`
      : `Les agents utilisent le Compte Claude ${donnees.actif}.`;
  }
  if (surFree.length) {
    pastille = (donnees.tousEpuises ? "" : pastille + " + ") + "Free";
    couleur = "text-blue-500";
    titre = `Sur Free Claude Code (gratuit) : ${surFree.join(", ")}. ` + titre;
  }
  if (retours.length) titre += ` ${retours.join(", ").replace(/^l/, "L")}.`;
  if (donnees && donnees.choix) titre += ` Choix dans Garde-fous Tabl : ${donnees.choix}.`;
  if (donnees && donnees.detail && donnees.detail.length) {
    titre += "\n\n" + donnees.detail.map((l) => `${l.nom} : ${l.source}${l.force ? " (forcé)" : ""}`).join("\n");
  }
  const sousTitre = [
    surFree.length ? `${surFree.length} agent${surFree.length > 1 ? "s" : ""} sur Free Claude Code` : null,
    ...retours,
  ].filter(Boolean);

  return h(
    "div",
    {
      title: titre,
      className: "flex w-full items-center gap-2.5 px-3 py-2 text-[13px] font-medium text-foreground/80",
    },
    h("span", { className: "relative shrink-0" }, h(Puce)),
    h(
      "span",
      { className: "flex min-w-0 flex-1 flex-col text-left" },
      h("span", { className: "truncate" }, "Compte Claude"),
      sousTitre.length
        ? h("span", { className: "truncate text-[11px] font-normal text-muted-foreground" }, sousTitre.join(" · "))
        : null,
    ),
    h("span", { className: "rounded px-1.5 text-[11px] tabular-nums " + couleur }, pastille),
  );
}
