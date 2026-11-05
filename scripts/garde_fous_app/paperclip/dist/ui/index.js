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
