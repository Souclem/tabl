// Garde-fous Tabl : une case par garde-fou des agents automatiques.
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

struct VueGardeFous: View {
    @StateObject private var reglages = Reglages()

    private var nombreActifs: Int { reglages.actifs.values.filter { $0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        .frame(width: 480)
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
