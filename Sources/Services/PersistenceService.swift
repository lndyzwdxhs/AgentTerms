import Foundation

struct PersistenceService {
    static let baseDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".agentterms", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var configURL: URL {
        Self.baseDir.appendingPathComponent("config.json")
    }

    func save(workspaces: [Workspace]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(workspaces)
            try data.write(to: configURL, options: .atomic)
        } catch {
            print("[Mast] Failed to save config: \(error)")
        }
    }

    func load() -> [Workspace] {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode([Workspace].self, from: data)
        } catch {
            print("[Mast] Failed to load config: \(error)")
            return []
        }
    }
}
