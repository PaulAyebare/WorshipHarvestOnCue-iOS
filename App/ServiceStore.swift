import Combine
import Foundation

enum WorshipStorage {
    static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    static var rootDirectory: URL {
        // Keep this legacy folder name stable so app updates retain local service data.
        applicationSupport.appendingPathComponent("WorshipFlow", isDirectory: true)
    }

    static var servicesDirectory: URL {
        rootDirectory.appendingPathComponent("Services", isDirectory: true)
    }

    static var servicesIndexURL: URL {
        rootDirectory.appendingPathComponent("services.json")
    }

    static var legacyAudioDirectory: URL {
        applicationSupport.appendingPathComponent("WorshipAudio", isDirectory: true)
    }

    static func serviceDirectory(for id: UUID) -> URL {
        servicesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }
}

struct WorshipService: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var date: Date

    init(id: UUID = UUID(), name: String, date: Date) {
        self.id = id
        self.name = name
        self.date = date
    }
}

@MainActor
final class ServiceStore: ObservableObject {
    static let maximumServices = 8

    @Published private(set) var services: [WorshipService] = []
    @Published private(set) var statusMessage: String?

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()

    init() {
        loadServices()
    }

    var canCreateService: Bool {
        services.count < Self.maximumServices
    }

    func createService(name: String, date: Date) throws -> WorshipService {
        guard canCreateService else {
            throw ServiceStoreError.serviceLimitReached
        }
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            throw ServiceStoreError.nameRequired
        }

        let service = WorshipService(name: cleanedName, date: date)
        try fileManager.createDirectory(at: WorshipStorage.serviceDirectory(for: service.id), withIntermediateDirectories: true)
        services.append(service)
        do {
            try saveServices()
        } catch {
            services.removeAll { $0.id == service.id }
            try? fileManager.removeItem(at: WorshipStorage.serviceDirectory(for: service.id))
            throw error
        }
        statusMessage = nil
        return service
    }

    func duplicateService(id: UUID) throws -> WorshipService {
        guard canCreateService else {
            throw ServiceStoreError.serviceLimitReached
        }
        guard let source = services.first(where: { $0.id == id }) else {
            throw ServiceStoreError.serviceNotFound
        }

        let duplicate = WorshipService(name: "\(source.name) (Copy)", date: source.date)
        let sourceDirectory = WorshipStorage.serviceDirectory(for: source.id)
        let duplicateDirectory = WorshipStorage.serviceDirectory(for: duplicate.id)
        let previousServices = services

        do {
            try fileManager.copyItem(at: sourceDirectory, to: duplicateDirectory)
            services.append(duplicate)
            try saveServices()
        } catch {
            services = previousServices
            try? fileManager.removeItem(at: duplicateDirectory)
            throw error
        }

        statusMessage = nil
        return duplicate
    }

    func deleteService(id: UUID) throws {
        guard let service = services.first(where: { $0.id == id }) else { return }
        let previous = services
        services.removeAll { $0.id == id }
        do {
            try saveServices()
        } catch {
            services = previous
            throw error
        }

        do {
            let folder = WorshipStorage.serviceDirectory(for: service.id)
            if fileManager.fileExists(atPath: folder.path) {
                try fileManager.removeItem(at: folder)
            }
            statusMessage = nil
        } catch {
            services = previous
            try? saveServices()
            throw error
        }
    }

    func updateService(id: UUID, name: String, date: Date) throws {
        guard let index = services.firstIndex(where: { $0.id == id }) else { return }
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else {
            throw ServiceStoreError.nameRequired
        }

        let previous = services
        services[index].name = cleanedName
        services[index].date = date
        do {
            try saveServices()
        } catch {
            services = previous
            throw error
        }
        statusMessage = nil
    }

    private func loadServices() {
        do {
            try fileManager.createDirectory(at: WorshipStorage.servicesDirectory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: WorshipStorage.servicesIndexURL.path) {
                let data = try Data(contentsOf: WorshipStorage.servicesIndexURL)
                let saved = try JSONDecoder().decode([WorshipService].self, from: data)
                services = Array(saved.sorted { $0.date < $1.date }.prefix(Self.maximumServices))
            } else {
                try migrateExistingAudioIfNeeded()
            }
        } catch {
            statusMessage = "Services could not be loaded: \(error.localizedDescription)"
        }
    }

    private func migrateExistingAudioIfNeeded() throws {
        let oldFolder = WorshipStorage.legacyAudioDirectory
        let oldState = oldFolder.appendingPathComponent("library.json")
        guard fileManager.fileExists(atPath: oldState.path) else {
            services = []
            return
        }

        let service = WorshipService(name: "Existing Service", date: Calendar.current.startOfDay(for: Date()))
        let newFolder = WorshipStorage.serviceDirectory(for: service.id)
        try fileManager.copyItem(at: oldFolder, to: newFolder)
        services = [service]
        do {
            try saveServices()
            try? fileManager.removeItem(at: oldFolder)
        } catch {
            services = []
            throw error
        }
    }

    private func saveServices() throws {
        try fileManager.createDirectory(at: WorshipStorage.rootDirectory, withIntermediateDirectories: true)
        services.sort { $0.date < $1.date }
        try encoder.encode(services).write(to: WorshipStorage.servicesIndexURL, options: .atomic)
    }
}

enum ServiceStoreError: LocalizedError {
    case serviceLimitReached
    case nameRequired
    case serviceNotFound

    var errorDescription: String? {
        switch self {
        case .serviceLimitReached:
            return "You can keep up to eight services on this device. Delete a service before creating another."
        case .nameRequired:
            return "Enter a name for this service."
        case .serviceNotFound:
            return "That service could not be found. Please try again."
        }
    }
}
