import Foundation
import Observation

/// A profile is one isolated cookie jar, so each can be signed into a different Google account.
struct Profile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
}

@MainActor
@Observable
final class ProfileStore {
    @ObservationIgnored private let defaults = UserDefaults.standard
    private(set) var profiles: [Profile]
    private(set) var currentID: UUID

    init() {
        let defaults = UserDefaults.standard
        var loaded = [Profile(id: UUID(), name: "Default")]
        if let data = defaults.data(forKey: "profiles"),
           let saved = try? JSONDecoder().decode([Profile].self, from: data),
           !saved.isEmpty {
            loaded = saved
        }
        let savedID = defaults.string(forKey: "currentProfile").flatMap(UUID.init(uuidString:))
        profiles = loaded
        currentID = loaded.first { $0.id == savedID }?.id ?? loaded[0].id
        save()
    }

    var current: Profile { profiles.first { $0.id == currentID }! }

    func select(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        currentID = id
        save()
    }

    @discardableResult
    func add(name: String) -> Profile {
        let profile = Profile(id: UUID(), name: name)
        profiles.append(profile)
        save()
        return profile
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[i].name = name
        save()
    }

    func remove(_ id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        if currentID == id { currentID = profiles[0].id }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(profiles), forKey: "profiles")
        defaults.set(currentID.uuidString, forKey: "currentProfile")
    }
}
