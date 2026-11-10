// Garde-fous Tabl : une case par garde-fou des agents automatiques, et en tête
// la liste « Compte des agents » (Automatique, Compte 1, Compte 2, Free Claude Code)
// et, par agent, le compte qu'il utilise et un choix pour le forcer.
//
// Coché = le geste est interdit aux agents (Paperclip…). Décoché = permis.
// Écrit ~/.config/tabl/garde_fous.json, que .claude/hooks/garde_fou_agents.py
// relit à chaque appel d'outil : l'effet est immédiat, sans rien relancer.
// Les identifiants doivent rester ceux de GARDE_FOUS dans ce script.
//
// Construire : scripts/garde_fous_app/construire.sh

import AppKit
import SwiftUI

struct GardeFou: Identifiable {
    let id: String
    let titre: String
    let detail: String
}

let gardeFous: [GardeFou] = [
    GardeFou(id: "supabase", titre: "CLI Supabase",
             detail: "db push, db query --linked, functions deploy, secrets… (« migration new » et « migration list » restent permis)"),
    GardeFou(id: "testflight", titre: "Builds TestFlight et App Store",
             detail: "flutter build ipa, xcodebuild archive, envoi par Transporter ou fastlane"),
    GardeFou(id: "scripts_prod", titre: "Scripts qui écrivent dans la vraie base",
             detail: "constellation_demo, photos_demo, donnees_demo, importer_annuaire, nettoyer_photos"),
    GardeFou(id: "api_supabase", titre: "Appels directs aux serveurs Supabase",
             detail: "curl ou autre vers supabase.co / supabase.com"),
    GardeFou(id: "secrets", titre: "Secrets",
             detail: "~/.config/tabl, clés d'API, trousseau du Mac"),
    GardeFou(id: "push_main", titre: "Push sur main et push forcé",
             detail: "les agents travaillent sur une branche, tu fusionnes"),
]

final class Reglages: ObservableObject {
    @Published var actifs: [String: Bool] = [:]
    @Published var erreur: String?

    let fichier: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/tabl/garde_fous.json")

    init() { charger() }

    /// Absent ou illisible = tout actif, comme dans le garde-fou.
    func charger() {
        var lus: [String: Any] = [:]
        if let donnees = try? Data(contentsOf: fichier),
           let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any] {
            lus = objet
        }
        actifs = Dictionary(uniqueKeysWithValues: gardeFous.map { g in
            (g.id, (lus[g.id] as? Bool) ?? true)
        })
    }

    func enregistrer() {
        do {
            try FileManager.default.createDirectory(
                at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
            let donnees = try JSONSerialization.data(
                withJSONObject: actifs, options: [.prettyPrinted, .sortedKeys])
            try donnees.write(to: fichier, options: .atomic)
            erreur = nil
        } catch {
            erreur = "Impossible d'enregistrer : \(error.localizedDescription)"
        }
    }

    func caseDe(_ id: String) -> Binding<Bool> {
        Binding(
            get: { self.actifs[id] ?? true },
            set: { self.actifs[id] = $0; self.enregistrer() })
    }

    func tout(_ valeur: Bool) {
        for g in gardeFous { actifs[g.id] = valeur }
        enregistrer()
    }
}

// Compte des agents : le choix du propriétaire, écrit dans
// ~/.config/tabl/choix_compte.json ({"choix": …, "agents": {nom: …}}) et appliqué
// dans la minute par la bascule automatique (~/.config/tabl/bascule_comptes.py,
// hors dépôt). Elle écrit le détail par agent (clé "affichage") dans
// bascule_comptes_etat.json. Les identifiants doivent rester ceux de
// LIBELLES_CHOIX et de lire_choix() dans ce script.
struct OptionCompte: Identifiable {
    let id: String
    let titre: String
}

let optionsCompte: [OptionCompte] = [
    OptionCompte(id: "auto", titre: "Automatique"),
    OptionCompte(id: "compte1", titre: "Compte Claude 1"),
    OptionCompte(id: "compte2", titre: "Compte Claude 2"),
    OptionCompte(id: "free", titre: "Free Claude Code (gratuit)"),
]

/// Choix forcé d'un agent ; "" = il suit le choix général.
let optionsAgent: [OptionCompte] = [
    OptionCompte(id: "", titre: "Suit le choix général"),
    OptionCompte(id: "compte1", titre: "Compte Claude 1"),
    OptionCompte(id: "compte2", titre: "Compte Claude 2"),
    OptionCompte(id: "free", titre: "Free Claude Code"),
]

/// Agents qui ont le jeton Supabase dans leurs variables d'environnement.
let agentsAvecJetonSupabase: Set<String> = ["Testeur", "Développeur Supabase"]

struct LigneAgent: Identifiable {
    let id: String
    let nom: String
    let source: String
    let auTravail: Bool
}

final class CompteAgents: ObservableObject {
    @Published var choix = "auto"
    @Published var forces: [String: String] = [:]
    @Published var lignes: [LigneAgent] = []
    @Published var erreur: String?

    private let dossier = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/tabl")
    private var fichierChoix: URL { dossier.appendingPathComponent("choix_compte.json") }

    init() { charger() }

    private func lireJson(_ nom: String) -> [String: Any] {
        guard let donnees = try? Data(contentsOf: dossier.appendingPathComponent(nom)),
              let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any]
        else { return [:] }
        return objet
    }

    func charger() {
        let lu = lireJson("choix_compte.json")
        let general = lu["choix"] as? String ?? "auto"
        choix = optionsCompte.contains { $0.id == general } ? general : "auto"
        forces = (lu["agents"] as? [String: String] ?? [:])
            .filter { ["compte1", "compte2", "free"].contains($0.value) }
        lireEtat()
    }

    /// Ce que chaque agent utilise vraiment, d'après la bascule (mis à jour chaque minute).
    func lireEtat() {
        let affichage = lireJson("bascule_comptes_etat.json")["affichage"] as? [[String: Any]] ?? []
        lignes = affichage.compactMap { l in
            guard let id = l["id"] as? String, let nom = l["nom"] as? String else { return nil }
            return LigneAgent(id: id, nom: nom, source: l["source"] as? String ?? "?",
                              auTravail: (l["statut"] as? String) == "running")
        }
    }

    private func enregistrer() {
        do {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
            let donnees = try JSONSerialization.data(
                withJSONObject: ["choix": choix, "agents": forces], options: [.prettyPrinted, .sortedKeys])
            try donnees.write(to: fichierChoix, options: .atomic)
            erreur = nil
        } catch {
            erreur = "Impossible d'enregistrer : \(error.localizedDescription)"
        }
    }

    func choisir(_ id: String) {
        choix = id
        enregistrer()
    }

    func forcer(_ nom: String, _ id: String) {
        if id.isEmpty { forces.removeValue(forKey: nom) } else { forces[nom] = id }
        enregistrer()
    }

    var explication: String {
        switch choix {
        case "compte1", "compte2":
            return "Tous les agents restent sur ce compte, même épuisé : ils attendent sa remise à zéro."
        case "free":
            return "Le Chef de projet, le Développeur Flutter et l'Analyste passent sur les modèles gratuits de NVIDIA. Les autres restent sur Claude (sécurité, Dépanneur, et ceux qui ont le jeton Supabase)."
        default:
            return "Compte 1, puis Compte 2 quand il est épuisé. Si les deux le sont : Free Claude Code pour le Chef, Flutter et l'Analyste, jusqu'au retour d'un compte."
        }
    }
}

struct VueCompte: View {
    @StateObject private var compte = CompteAgents()
    private let minuterie = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private func couleur(_ source: String) -> Color {
        if source.contains("épuisé") || source == "aucun compte" { return .red }
        return source.hasPrefix("Free") ? .blue : .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compte des agents").font(.title2.bold())
            Picker("Compte", selection: Binding(get: { compte.choix }, set: { compte.choisir($0) })) {
                ForEach(optionsCompte) { Text($0.titre).tag($0.id) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 280, alignment: .leading)
            Text(compte.explication + " Appliqué dans la minute.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Par agent").font(.headline).padding(.top, 6)
            if compte.lignes.isEmpty {
                Text("Le détail apparaît dans une minute (la bascule le note à chaque passage).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(compte.lignes) { ligne in
                    GridRow {
                        HStack(spacing: 6) {
                            Circle().fill(ligne.auTravail ? Color.green : Color.secondary.opacity(0.3))
                                .frame(width: 7, height: 7)
                                .help(ligne.auTravail ? "Au travail" : "Au repos")
                            Text(ligne.nom)
                        }
                        Text(ligne.source).foregroundStyle(couleur(ligne.source)).font(.callout)
                        Picker(ligne.nom, selection: Binding(
                            get: { compte.forces[ligne.nom] ?? "" },
                            set: { compte.forcer(ligne.nom, $0) })) {
                            ForEach(optionsAgent) { Text($0.titre).tag($0.id) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 190)
                    }
                    if compte.forces[ligne.nom] == "free" && agentsAvecJetonSupabase.contains(ligne.nom) {
                        GridRow {
                            Text("")
                            Text("Son jeton Supabase peut partir chez NVIDIA.")
                                .font(.caption).foregroundStyle(.orange)
                                .gridCellColumns(2)
                        }
                    }
                }
            }
            Text("Point vert : agent au travail. Un changement vaut pour son prochain passage ; celui en cours finit sur l'ancien compte.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let erreur = compte.erreur {
                Text(erreur).font(.caption).foregroundStyle(.red)
            }
        }
        .onReceive(minuterie) { _ in compte.lireEtat() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            compte.charger()
        }
    }
}

struct VueGardeFous: View {
    @StateObject private var reglages = Reglages()

    private var nombreActifs: Int { reglages.actifs.values.filter { $0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VueCompte()

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Garde-fous des agents").font(.title2.bold())
                Text("Coché = interdit aux agents Paperclip. Décoché = permis. Effet immédiat.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(gardeFous) { g in
                    Toggle(isOn: reglages.caseDe(g.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.titre)
                            Text(g.detail).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Divider()

            HStack {
                Button("Tout cocher") { reglages.tout(true) }
                Button("Tout décocher") { reglages.tout(false) }
                Spacer()
                Text("\(nombreActifs) sur \(gardeFous.count) actifs")
                    .font(.caption).foregroundStyle(nombreActifs == gardeFous.count ? .green : .orange)
            }

            Text("Toujours actif : un agent ne peut ni modifier ces réglages, ni le garde-fou lui-même. Tes sessions à toi ne sont jamais bloquées.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let erreur = reglages.erreur {
                Text(erreur).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(22)
        .frame(width: 620)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            reglages.charger()
        }
    }
}

final class Delegue: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct GardeFousTabl: App {
    @NSApplicationDelegateAdaptor(Delegue.self) private var delegue

    var body: some Scene {
        WindowGroup("Garde-fous Tabl") { VueGardeFous() }
            .windowResizability(.contentSize)
    }
}
