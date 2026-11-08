#!/usr/bin/env python3
"""Tests du garde-fou des agents réécrit (TAB-32, corrige le rapport TAB-9).

Lancer :  python3 scripts/garde_fou_proposition/test_garde_fou.py

Les cas vivent dans cas.json : ce fichier-ci ne cite aucun geste réservé en
clair, pour qu'un agent puisse le lancer sans être refusé par le garde-fou.
Chaque cas donne l'outil, son entrée et le verdict attendu (« refus » ou « passe »).
Les cas « refus » couvrent les contournements du rapport TAB-9 ; les cas « passe »,
les faux positifs du rapport et les gestes légitimes qui doivent rester possibles.
"""
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", ".."))
SCRIPT = os.path.join(ICI, "garde_fou_agents.py")

spec = importlib.util.spec_from_file_location("garde_fou_agents", SCRIPT)
gf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gf)

TOUS = set(gf.GARDE_FOUS)


def git(dossier, *args):
    subprocess.run(["git", "-C", dossier, *args], check=True, capture_output=True,
                   env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
                        "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"})


class BaseDeTest(unittest.TestCase):
    """Environnement fixe : dossier temporaire, deux dépôts git (main et feature/x), variables Paperclip."""

    @classmethod
    def setUpClass(cls):
        cls.tmp_objet = tempfile.TemporaryDirectory()
        cls.tmp = os.path.realpath(cls.tmp_objet.name)
        cls.main = os.path.join(cls.tmp, "depot_main")
        cls.branche = os.path.join(cls.tmp, "depot_branche")
        for dossier, nom in ((cls.main, "main"), (cls.branche, "feature/x")):
            os.makedirs(dossier)
            git(dossier, "init", "-q", "-b", "main")
            git(dossier, "commit", "-q", "--allow-empty", "-m", "init")
            if nom != "main":
                git(dossier, "checkout", "-q", "-b", nom)

    @classmethod
    def tearDownClass(cls):
        cls.tmp_objet.cleanup()

    def setUp(self):
        env = {"PAPERCLIP_API_URL": "http://localhost:3100", "PAPERCLIP_API_KEY": "cle",
               "CLAUDE_PROJECT_DIR": RACINE,
               "CLAUDE_CONFIG_DIR": os.path.join(self.tmp, "config_claude"),
               "HOME": os.path.join(self.tmp, "home_agent")}
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        ancien = os.getcwd()
        os.chdir(RACINE)
        self.addCleanup(os.chdir, ancien)

    def remplacer(self, valeur):
        if isinstance(valeur, str):
            for ancien, nouveau in (("/Users/{USER}", gf.DOSSIER_PERSO),
                                    ("{TMP}", self.tmp), ("{MAIN}", self.main), ("{BRANCHE}", self.branche),
                                    ("{CFG}", os.path.join(self.tmp, "config_claude")),
                                    ("{AGENT_HOME}", os.path.join(self.tmp, "home_agent"))):
                valeur = valeur.replace(ancien, nouveau)
            return valeur
        if isinstance(valeur, dict):
            return {cle: self.remplacer(v) for cle, v in valeur.items()}
        if isinstance(valeur, list):
            return [self.remplacer(v) for v in valeur]
        return valeur


class TestCasDuRapport(BaseDeTest):
    """Un test par cas de cas.json (sous-tests, un par ligne)."""

    def test_tous_les_cas(self):
        with open(os.path.join(ICI, "cas.json"), encoding="utf-8") as fichier:
            cas = json.load(fichier)
        self.assertGreater(len(cas), 300)
        for numero, un_cas in enumerate(cas):
            with self.subTest(numero=numero, section=un_cas["section"], cas=json.dumps(un_cas["entree"])[:120]):
                self.verifier(un_cas)

    def verifier(self, un_cas):
        un_cas = self.remplacer(un_cas)
        for nom, contenu in un_cas.get("fichiers", {}).items():
            chemin = os.path.join(self.tmp, nom)
            with open(chemin, "w", encoding="utf-8") as f:
                f.write(contenu)
            if un_cas.get("executable"):
                os.chmod(chemin, 0o755)
        if "lien" in un_cas:
            cible, nom = un_cas["lien"]
            lien = os.path.join(self.tmp, nom)
            if not os.path.lexists(lien):
                os.symlink(os.path.expanduser(cible.replace("~", gf.DOSSIER_PERSO, 1)), lien)
        actifs = set(un_cas["actifs"]) if "actifs" in un_cas else TOUS
        dossier = un_cas.get("cwd", RACINE)
        refus = gf.motif_de_refus(un_cas["outil"], un_cas["entree"], dossier, actifs)
        if un_cas["attendu"] == "refus":
            self.assertTrue(refus, "devrait être refusé")
            self.assertNotIn("Traceback", refus)
        else:
            self.assertIsNone(refus, f"ne devrait pas être refusé : {refus}")


class TestInterface(BaseDeTest):
    """Même interface que l'ancien hook : JSON sur stdin, code 2 + message sur stderr pour un refus."""

    def lancer(self, donnees, env_extra=None, brut=None):
        env = {k: v for k, v in os.environ.items() if not k.startswith("PAPERCLIP_")}
        env.pop("TABL_AGENT_AUTOMATIQUE", None)
        env.update(env_extra or {})
        entree = brut if brut is not None else json.dumps(donnees)
        return subprocess.run([sys.executable, SCRIPT], input=entree, capture_output=True, text=True,
                              env=env, cwd=RACINE)

    def test_hors_agent_rien_n_est_refuse(self):
        geste = {"tool_name": "Write", "tool_input": {"file_path": ".claude/hooks/garde_fou_agents.py"}}
        self.assertEqual(self.lancer(geste).returncode, 0)

    def test_agent_paperclip_refus_code_2_et_message(self):
        geste = {"tool_name": "Write", "tool_input": {"file_path": ".claude/hooks/garde_fou_agents.py"},
                 "cwd": RACINE}
        r = self.lancer(geste, {"PAPERCLIP_AGENT_ID": "x"})
        self.assertEqual(r.returncode, 2)
        self.assertIn("Refusé par le garde-fou des agents de Tabl", r.stderr)
        self.assertEqual(r.stdout, "")

    def test_agent_automatique_variable_dediee(self):
        geste = {"tool_name": "Edit", "tool_input": {"file_path": ".claude/settings.json"}, "cwd": RACINE}
        self.assertEqual(self.lancer(geste, {"TABL_AGENT_AUTOMATIQUE": "1"}).returncode, 2)

    def test_agent_geste_ordinaire_passe(self):
        geste = {"tool_name": "Bash", "tool_input": {"command": "git status"}, "cwd": RACINE}
        r = self.lancer(geste, {"PAPERCLIP_AGENT_ID": "x"})
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stderr, "")

    def test_entree_illisible_refusee_par_prudence(self):
        for brut in ("", "pas du json", "[1,2]", "null"):
            with self.subTest(brut=brut):
                r = self.lancer(None, {"PAPERCLIP_AGENT_ID": "x"}, brut=brut)
                self.assertEqual(r.returncode, 2)
                self.assertIn("illisible", r.stderr)

    def test_outil_inconnu_sans_chemin_passe(self):
        geste = {"tool_name": "TodoWrite", "tool_input": {"todos": []}, "cwd": RACINE}
        self.assertEqual(self.lancer(geste, {"PAPERCLIP_AGENT_ID": "x"}).returncode, 0)


class TestReglages(BaseDeTest):
    """Fichier de réglages : décoché = désactivé ; absent ou illisible = tous actifs."""

    def avec_reglages(self, contenu):
        chemin = os.path.join(self.tmp, "reglages.json")
        if contenu is None:
            if os.path.exists(chemin):
                os.remove(chemin)
        else:
            with open(chemin, "w", encoding="utf-8") as f:
                f.write(contenu)
        return mock.patch.object(gf, "REGLAGES", chemin)

    def test_fichier_absent_tout_actif(self):
        with self.avec_reglages(None):
            self.assertEqual(gf.garde_fous_actifs(), TOUS)

    def test_fichier_illisible_tout_actif(self):
        for contenu in ("", "{pas du json", "[]", "42", "null"):
            with self.subTest(contenu=contenu), self.avec_reglages(contenu):
                self.assertEqual(gf.garde_fous_actifs(), TOUS)

    def test_decoche_un_seul(self):
        with self.avec_reglages(json.dumps({"supabase": False})):
            self.assertEqual(gf.garde_fous_actifs(), TOUS - {"supabase"})

    def test_valeur_non_booleenne_reste_active(self):
        with self.avec_reglages(json.dumps({"supabase": "non", "secrets": 0, "push_main": None})):
            self.assertEqual(gf.garde_fous_actifs(), TOUS)

    def test_identifiants_inconnus_ignores(self):
        with self.avec_reglages(json.dumps({"inconnu": False, "testflight": False})):
            self.assertEqual(gf.garde_fous_actifs(), TOUS - {"testflight"})

    def test_identifiants_identiques_a_l_app(self):
        self.assertEqual(set(gf.GARDE_FOUS),
                         {"supabase", "testflight", "scripts_prod", "api_supabase", "secrets", "push_main"})

    def test_main_respecte_un_garde_fou_decoche(self):
        geste = {"tool_name": "Bash", "tool_input": {"command": "flutter build " + "ipa"}, "cwd": RACINE}

        def lancer():
            with mock.patch("sys.stdin", io.StringIO(json.dumps(geste))), \
                    mock.patch("sys.stderr", io.StringIO()):
                return gf.main()

        with mock.patch.dict(os.environ, {"PAPERCLIP_AGENT_ID": "x"}):
            with self.avec_reglages(None):
                self.assertEqual(lancer(), 2)
            with self.avec_reglages(json.dumps({"testflight": False})):
                self.assertEqual(lancer(), 0)

    def test_le_garde_fou_se_protege_meme_tout_decoche(self):
        tout_decoche = json.dumps({nom: False for nom in gf.GARDE_FOUS})
        geste = {"tool_name": "Write", "tool_input": {"file_path": ".claude/hooks/garde_fou_agents.py"},
                 "cwd": RACINE}
        with mock.patch.dict(os.environ, {"PAPERCLIP_AGENT_ID": "x"}), self.avec_reglages(tout_decoche), \
                mock.patch("sys.stdin", io.StringIO(json.dumps(geste))), mock.patch("sys.stderr", io.StringIO()):
            self.assertEqual(gf.main(), 2)


class TestAnalyse(BaseDeTest):
    """Quelques propriétés de l'analyse qui ne se résument pas à « refus / passe »."""

    def refus(self, commande, **kw):
        return gf.motif_de_refus("Bash", {"command": commande}, kw.get("cwd", RACINE), kw.get("actifs", TOUS))

    def test_le_message_explique_quoi_faire(self):
        self.assertIn("propriétaire", self.refus("supabase db " + "push"))

    def test_commande_vide_ou_commentaire(self):
        for commande in ("", "   ", "# juste un commentaire", "\n\n"):
            with self.subTest(commande=commande):
                self.assertIsNone(self.refus(commande))

    def test_commande_tres_longue_ne_plante_pas(self):
        self.assertIsNone(self.refus("echo " + "a" * 200_000))

    def test_profondeur_maximale_refusee_en_cas_de_doute(self):
        commande = "supabase db " + "push"
        for _ in range(10):
            commande = "bash -c " + json.dumps(commande)
        self.assertTrue(self.refus(commande))

    def test_guillemets_non_fermes_refuses(self):
        self.assertTrue(self.refus("echo 'abc; supabase db " + "push"))

    def test_sans_garde_fou_actif_rien_d_opaque_n_est_refuse(self):
        self.assertIsNone(self.refus("sh -c \"$INCONNU\"", actifs=set()))

    def test_variable_paperclip_definie_dans_la_commande(self):
        commande = ('PAPERCLIP_API_BASE="${PAPERCLIP_API_URL%/}"; '
                    'curl -s "$PAPERCLIP_API_BASE/api/issues/x"')
        self.assertIsNone(self.refus(commande))

    def test_variable_paperclip_non_definie_refusee(self):
        self.assertTrue(self.refus('curl -s "$PAPERCLIP_API_BASE/api/issues/x"'))

    def test_script_modifie_apres_ecriture_est_relu(self):
        script = os.path.join(self.tmp, "relu.sh")
        with open(script, "w", encoding="utf-8") as f:
            f.write("ls\n")
        self.assertIsNone(self.refus(f"bash {script}"))
        with open(script, "w", encoding="utf-8") as f:
            f.write("supabase db " + "push\n")
        self.assertTrue(self.refus(f"bash {script}"))

    def test_script_absent_sans_effet(self):
        self.assertIsNone(self.refus(f"bash {self.tmp}/n_existe_pas.sh"))

    def test_lien_symbolique_vers_le_hook(self):
        lien = os.path.join(self.tmp, "lien_hook")
        if not os.path.lexists(lien):
            os.symlink(os.path.join(RACINE, ".claude", "hooks"), lien)
        entree = {"file_path": os.path.join(lien, "garde_fou_agents.py"), "content": "x"}
        self.assertTrue(gf.motif_de_refus("Write", entree, RACINE, TOUS))
        self.assertTrue(self.refus(f"echo x > {lien}/garde_fou_agents.py"))
        self.assertIsNone(gf.motif_de_refus("Read", {"file_path": entree["file_path"]}, RACINE, TOUS))

    def test_majuscules_et_unicode_dans_les_chemins(self):
        self.assertTrue(self.refus("cat ~/.CONFIG/TABL/garde_fous.json"))
        self.assertTrue(self.refus("cat ~/.config/Tabl/x"))

    def test_branche_protegee_detectee_dans_un_depot_reel(self):
        self.assertTrue(self.refus("git push", cwd=self.main))
        self.assertIsNone(self.refus("git push", cwd=self.branche))

    def test_multiedit_et_notebookedit(self):
        for outil, champ in (("MultiEdit", "file_path"), ("NotebookEdit", "notebook_path")):
            with self.subTest(outil=outil):
                self.assertTrue(gf.motif_de_refus(outil, {champ: ".claude/settings.local.json"}, RACINE, TOUS))
                self.assertIsNone(gf.motif_de_refus(outil, {champ: "app/lib/main.dart"}, RACINE, TOUS))


if __name__ == "__main__":
    unittest.main(verbosity=1)
