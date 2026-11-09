import AVFoundation
import Combine
import Foundation

private struct PreparedAudioPlayer: @unchecked Sendable {
    let player: AVAudioPlayer
}

@MainActor
final class AudioLibrary: NSObject, ObservableObject {
    @Published private(set) var songs: [AudioSlot]
    @Published private(set) var loops: [AudioSlot]
    @Published private(set) var pads: [AudioSlot]
    @Published private(set) var flowOrder: [ServiceSection] = []
    @Published private(set) var notes = ""
    @Published private(set) var playingSongIndices: Set<Int> = []
    @Published private(set) var playingLoopIndex: Int?
    @Published private(set) var playingPadIndices: Set<Int> = []
    @Published private(set) var nowPlaying = "Nothing playing"
    @Published private(set) var currentSongLabel: String?
    @Published private(set) var songElapsedTime: TimeInterval = 0
    @Published private(set) var songDuration: TimeInterval = 0
    @Published private(set) var isCurrentSongPlaying = false
    @Published var playbackMode: SongPlaybackMode = .crossfade
    @Published var fadeDuration: TimeInterval = 4
    @Published private(set) var statusMessage: String?

    private struct PlaybackKey: Hashable {
        let group: AudioGroup
        let slotID: UUID
    }

    private final class ActivePlayback {
        let key: PlaybackKey
        let player: AVAudioPlayer

        init(key: PlaybackKey, player: AVAudioPlayer) {
            self.key = key
            self.player = player
        }
    }

    private var players: [PlaybackKey: ActivePlayback] = [:]
    private var transitionTask: Task<Void, Never>?
    private var songProgressTask: Task<Void, Never>?
    private var transitionGeneration = 0
    private var padTransitionGeneration = 0
    private var loopTransitionInProgress = false
    private var currentSongID: UUID?
    private var audioSessionConfigurationTask: Task<Void, Error>?
    private let serviceID: UUID
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()

    private var libraryDirectory: URL {
        WorshipStorage.serviceDirectory(for: serviceID)
    }

    private var stateURL: URL {
        libraryDirectory.appendingPathComponent("library.json")
    }

    init(serviceID: UUID) {
        self.serviceID = serviceID
        let defaultSongs = Self.defaultSongs()
        let defaultLoops = Self.defaultLoops()
        let defaultPads = Self.defaultPads()
        var migrated = false
        var loadedSongs = defaultSongs
        var loadedLoops = defaultLoops
        var loadedPads = defaultPads
        var loadedFlowOrder = Self.defaultSections(songs: defaultSongs, loops: defaultLoops)
        var loadedNotes = ""

        if let data = try? Data(contentsOf: Self.stateFileURL(serviceID: serviceID)),
           let saved = try? JSONDecoder().decode(AudioLibraryState.self, from: data) {
            if saved.schemaVersion < 2 {
                loadedSongs = Self.migrateLegacySongs(saved.songs, defaults: defaultSongs)
                loadedLoops = Self.migrateLegacyLoops(saved.loops, defaults: defaultLoops)
                migrated = true
            } else {
                loadedSongs = Self.fit(saved.songs, to: defaultSongs)
                loadedLoops = Self.fit(saved.loops, to: defaultLoops)
            }
            loadedPads = Self.fit(saved.pads, to: defaultPads)
            let savedSections = saved.sections ?? Self.migrateSections(from: saved.flowOrder, songs: loadedSongs, loops: loadedLoops)
            loadedFlowOrder = Self.validSections(savedSections, songs: loadedSongs, loops: loadedLoops)
            loadedNotes = String(saved.notes.prefix(600))
        }

        songs = loadedSongs
        loops = loadedLoops
        pads = loadedPads
        flowOrder = loadedFlowOrder
        notes = loadedNotes

        super.init()
        createLibraryDirectoryIfNeeded()
        refreshPlaybackState()
        if migrated { try? saveLibrary() }
    }

    private static func stateFileURL(serviceID: UUID) -> URL {
        WorshipStorage.serviceDirectory(for: serviceID).appendingPathComponent("library.json")
    }

    private static func defaultSongs() -> [AudioSlot] {
        ["High Praise 1", "High Praise 2", "High Praise 3", "High Praise 4",
         "Adoration 1", "Adoration 2", "Adoration 3", "Dance Team",
         "Special Song", "Response Song 1", "Response Song 2", "Response Song 3",
         "Adoration 4", "Response Song 4"]
            .map { AudioSlot(label: $0) }
    }

    private static func defaultLoops() -> [AudioSlot] {
        ["Pre-service Loop", "Prayer Loop", "Service Host Loop", "Serving / Testimony Loop",
         "Giving Exhortation Loop", "Welcome the Speaker Loop", "Response Moment Loop", "Post-service Loop"]
            .map { AudioSlot(label: $0) }
    }

    private static func defaultPads() -> [AudioSlot] {
        ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
            .map { AudioSlot(label: $0) }
    }

    private static func defaultSections(songs: [AudioSlot], loops: [AudioSlot]) -> [ServiceSection] {
        func songIDs(_ indices: [Int]) -> [UUID] { indices.compactMap { songs.indices.contains($0) ? songs[$0].id : nil } }
        func loopID(_ index: Int) -> UUID? { loops.indices.contains(index) ? loops[index].id : nil }
        return [
            ServiceSection(title: "Pre-service", kind: .loop, loopSlotID: loopID(0), isBuiltIn: true),
            ServiceSection(title: "High Praise", kind: .songs, songSlotIDs: songIDs([0, 1, 2, 3]), isBuiltIn: true),
            ServiceSection(title: "Exhortation and Prayer", kind: .loop, loopSlotID: loopID(1), isBuiltIn: true),
            ServiceSection(title: "Adoration", kind: .songs, songSlotIDs: songIDs([4, 5, 6, 12]), isBuiltIn: true),
            ServiceSection(title: "Service Host", kind: .loop, loopSlotID: loopID(2), isBuiltIn: true),
            ServiceSection(title: "Serving Moment / Testimony Time", kind: .loop, loopSlotID: loopID(3), isBuiltIn: true),
            ServiceSection(title: "Dance Team", kind: .specialMusic, songSlotIDs: songIDs([7]), isBuiltIn: true),
            ServiceSection(title: "Giving Exhortation", kind: .loop, loopSlotID: loopID(4), isBuiltIn: true),
            ServiceSection(title: "Special Song", kind: .specialMusic, songSlotIDs: songIDs([8]), isBuiltIn: true),
            ServiceSection(title: "Welcome the Speaker", kind: .loop, loopSlotID: loopID(5), isBuiltIn: true),
            ServiceSection(title: "Response / Ministry Moment", kind: .responseMinistry, songSlotIDs: songIDs([9, 10, 11, 13]), loopSlotID: loopID(6), isBuiltIn: true),
            ServiceSection(title: "Post-service", kind: .loop, loopSlotID: loopID(7), isBuiltIn: true)
        ]
    }

    private static func migrateSections(from legacy: [FlowSegment], songs: [AudioSlot], loops: [AudioSlot]) -> [ServiceSection] {
        let defaults = defaultSections(songs: songs, loops: loops)
        let idBySegment: [FlowSegment: Int] = [.preService: 0, .highPraise: 1, .exhortationPrayer: 2, .adoration: 3, .serviceHost: 4, .servingMoment: 5, .danceTeam: 6, .givingExhortation: 7, .specialSong: 8, .welcomeSpeaker: 9, .responseMinistry: 10]
        return legacy.compactMap { segment in idBySegment[segment].map { defaults[$0] } } + [defaults[11]]
    }

    private static func validSections(_ sections: [ServiceSection], songs: [AudioSlot], loops: [AudioSlot]) -> [ServiceSection] {
        let songIDs = Set(songs.map(\.id)), loopIDs = Set(loops.map(\.id))
        let valid = sections.map { section -> ServiceSection in
            var result = section
            result.songSlotIDs = result.songSlotIDs.filter(songIDs.contains)
            if let id = result.loopSlotID, !loopIDs.contains(id) { result.loopSlotID = nil }
            return result
        }
        return valid
    }

    private static func fit(_ saved: [AudioSlot], to defaults: [AudioSlot]) -> [AudioSlot] {
        guard saved.count < defaults.count else { return saved }
        return saved + Array(defaults.dropFirst(saved.count))
    }

    private static func migrateLegacyLoops(_ saved: [AudioSlot], defaults: [AudioSlot]) -> [AudioSlot] {
        var result = defaults
        let legacyToNewIndex = [0: 0, 1: 1, 2: 4, 3: 7]
        for (legacyIndex, newIndex) in legacyToNewIndex where saved.indices.contains(legacyIndex) {
            result[newIndex] = saved[legacyIndex]
        }
        return result
    }

    private static func migrateLegacySongs(_ saved: [AudioSlot], defaults: [AudioSlot]) -> [AudioSlot] {
        var result = defaults
        for index in 0..<min(saved.count, 7) {
            result[index] = saved[index]
        }
        if saved.count > 7 { result[8] = saved[7] }
        return result
    }

    private func configureAudioSession() async throws {
        if let audioSessionConfigurationTask {
            try await audioSessionConfigurationTask.value
            return
        }

        let configurationTask = Task.detached(priority: .userInitiated) {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        }
        audioSessionConfigurationTask = configurationTask
        try await configurationTask.value
    }

    private func activateAudioSession() async throws {
        try await configureAudioSession()
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 27.0, *) {
            guard try await session.activate() else {
                throw NSError(domain: "WorshipAudio", code: 2, userInfo: [NSLocalizedDescriptionKey: "The audio session could not be activated."])
            }
        } else {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try session.setActive(true)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func createLibraryDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
        } catch {
            statusMessage = "On-device audio storage is unavailable: \(error.localizedDescription)"
        }
    }

    func slots(for group: AudioGroup) -> [AudioSlot] {
        switch group {
        case .songs: return songs
        case .loops: return loops
        case .pads: return pads
        }
    }

    func slot(for group: AudioGroup, at index: Int) -> AudioSlot {
        slots(for: group)[index]
    }

    func updateSlot(group: AudioGroup, index: Int, label: String, importedFile: URL?, originalFileName: String? = nil) throws {
        guard slots(for: group).indices.contains(index) else { return }
        var slot = slot(for: group, at: index)
        let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        slot.label = cleanedLabel.isEmpty ? slot.label : cleanedLabel

        if let importedFile {
            guard fileManager.fileExists(atPath: importedFile.path) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: importedFile.path])
            }
            let hasAccess = importedFile.startAccessingSecurityScopedResource()
            defer { if hasAccess { importedFile.stopAccessingSecurityScopedResource() } }

            let ext = importedFile.pathExtension.isEmpty ? "audio" : importedFile.pathExtension
            let storedName = "\(UUID().uuidString).\(ext)"
            let destination = libraryDirectory.appendingPathComponent(storedName)
            try fileManager.copyItem(at: importedFile, to: destination)
            guard fileManager.fileExists(atPath: destination.path) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: destination.path])
            }
            stopPlayback(for: group, slotID: slot.id)
            if let oldName = slot.storedFileName {
                try? fileManager.removeItem(at: libraryDirectory.appendingPathComponent(oldName))
            }
            slot.originalFileName = originalFileName.flatMap { $0.isEmpty ? nil : $0 } ?? importedFile.lastPathComponent
            slot.storedFileName = storedName
        }

        assign(slot, group: group, index: index)
        try saveLibrary()
        statusMessage = nil
    }

    func removeSlot(group: AudioGroup, index: Int) throws {
        guard slots(for: group).indices.contains(index) else { return }
        var slot = slot(for: group, at: index)
        stopPlayback(for: group, slotID: slot.id)
        if let oldName = slot.storedFileName {
            try? fileManager.removeItem(at: libraryDirectory.appendingPathComponent(oldName))
        }
        slot.originalFileName = nil
        slot.storedFileName = nil
        assign(slot, group: group, index: index)
        try saveLibrary()
    }

    func moveFlowSegments(from offsets: IndexSet, to destination: Int) {
        guard !offsets.isEmpty else { return }
        let moving = offsets.sorted().map { flowOrder[$0] }
        for index in offsets.sorted(by: >) { flowOrder.remove(at: index) }
        let adjustment = offsets.filter { $0 < destination }.count
        let insertion = max(0, min(flowOrder.count, destination - adjustment))
        flowOrder.insert(contentsOf: moving, at: insertion)
        try? saveLibrary()
    }

    func addSection(name: String, kind: ServiceSectionKind, songCount: Int = 4) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        let count: Int
        switch kind {
        case .loop: count = 0
        case .specialMusic: count = 1
        case .responseMinistry, .songs: count = min(4, max(1, songCount))
        }
        var songIDs: [UUID] = []
        if count > 0 {
            for number in 1...count {
                let slot = AudioSlot(label: "\(cleanedName) \(number)")
                songs.append(slot)
                songIDs.append(slot.id)
            }
        }
        var loopID: UUID?
        if kind == .loop || kind == .responseMinistry {
            let slot = AudioSlot(label: "\(cleanedName) Loop")
            loops.append(slot)
            loopID = slot.id
        }
        let section = ServiceSection(title: cleanedName, kind: kind, songSlotIDs: songIDs, loopSlotID: loopID)
        flowOrder.append(section)
        try? saveLibrary()
    }

    func renameSection(id: UUID, title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let index = flowOrder.firstIndex(where: { $0.id == id }) else { return }
        flowOrder[index].title = cleaned
        try? saveLibrary()
    }

    func resizeSongSlots(sectionID: UUID, count: Int) {
        guard let sectionIndex = flowOrder.firstIndex(where: { $0.id == sectionID }) else { return }
        let kind = flowOrder[sectionIndex].kind
        guard kind == .songs || kind == .responseMinistry else { return }
        let desiredCount = min(4, max(1, count))
        while flowOrder[sectionIndex].songSlotIDs.count > desiredCount {
            let slotID = flowOrder[sectionIndex].songSlotIDs.removeLast()
            removeOwnedSlot(id: slotID, group: .songs)
        }
        while flowOrder[sectionIndex].songSlotIDs.count < desiredCount {
            let number = flowOrder[sectionIndex].songSlotIDs.count + 1
            let slot = AudioSlot(label: "\(flowOrder[sectionIndex].title) \(number)")
            songs.append(slot)
            flowOrder[sectionIndex].songSlotIDs.append(slot.id)
        }
        try? saveLibrary()
        refreshPlaybackState()
    }

    func removeSection(id: UUID) {
        guard let index = flowOrder.firstIndex(where: { $0.id == id }) else { return }
        _ = beginTransition()
        loopTransitionInProgress = false
        let section = flowOrder.remove(at: index)
        for slotID in section.songSlotIDs {
            removeOwnedSlot(id: slotID, group: .songs)
        }
        if let slotID = section.loopSlotID { removeOwnedSlot(id: slotID, group: .loops) }
        try? saveLibrary()
        refreshPlaybackState()
    }

    private func removeOwnedSlot(id: UUID, group: AudioGroup) {
        let current = slots(for: group)
        guard let index = current.firstIndex(where: { $0.id == id }) else { return }
        stopPlayback(for: group, slotID: id)
        if let name = current[index].storedFileName {
            try? fileManager.removeItem(at: libraryDirectory.appendingPathComponent(name))
        }
        switch group {
        case .songs: songs.remove(at: index)
        case .loops: loops.remove(at: index)
        case .pads: break
        }
    }

    func moveSongSlot(from source: Int, to destination: Int, within sectionID: UUID) {
        guard let sectionIndex = flowOrder.firstIndex(where: { $0.id == sectionID }),
              flowOrder[sectionIndex].songSlotIDs.indices.contains(source),
              flowOrder[sectionIndex].songSlotIDs.indices.contains(destination),
              source != destination else { return }
        let slotID = flowOrder[sectionIndex].songSlotIDs.remove(at: source)
        flowOrder[sectionIndex].songSlotIDs.insert(slotID, at: destination)
        try? saveLibrary()
        refreshPlaybackState()
    }

    func setNotes(_ value: String) {
        let limited = String(value.prefix(600))
        guard limited != notes else { return }
        notes = limited
        try? saveLibrary()
    }

    private func assign(_ slot: AudioSlot, group: AudioGroup, index: Int) {
        switch group {
        case .songs: songs[index] = slot
        case .loops: loops[index] = slot
        case .pads: pads[index] = slot
        }
        refreshPlaybackState()
    }

    private func saveLibrary() throws {
        createLibraryDirectoryIfNeeded()
        let state = AudioLibraryState(songs: songs, loops: loops, pads: pads, flowOrder: FlowSegment.allCases, notes: notes, sections: flowOrder)
        try encoder.encode(state).write(to: stateURL, options: .atomic)
    }

    func playSong(at index: Int) {
        guard songs.indices.contains(index), let fileName = songs[index].storedFileName else { return }
        let key = PlaybackKey(group: .songs, slotID: songs[index].id)
        if players[key] != nil {
            let generation = beginTransition()
            let activeSongs = activePlayers(for: .songs)
            transitionTask = Task { @MainActor in
                _ = await self.fadeOut(activeSongs, duration: self.fadeDuration, generation: generation)
                if generation == self.transitionGeneration { self.refreshPlaybackState() }
            }
            return
        }

        let generation = beginTransition()
        loopTransitionInProgress = false
        let loopPlayers = activePlayers(for: .loops)
        let oldSongs = activePlayers(for: .songs)
        transitionTask = Task { @MainActor in
            if !loopPlayers.isEmpty {
                guard await self.fadeOut(loopPlayers, duration: self.fadeDuration, generation: generation) else { return }
            }
            guard generation == self.transitionGeneration else { return }

            do {
                try await self.activateAudioSession()
                guard generation == self.transitionGeneration else { return }
                if self.playbackMode == .crossfade, !oldSongs.isEmpty {
                    let newPlayback = try await self.makePlayback(group: .songs, index: index, fileName: fileName, volume: 0, loops: 0)
                    guard generation == self.transitionGeneration else {
                        self.stopImmediately(newPlayback)
                        return
                    }
                    await self.crossfade(oldSongs, into: newPlayback, duration: self.fadeDuration, generation: generation)
                } else {
                    if !oldSongs.isEmpty {
                        guard await self.fadeOut(oldSongs, duration: self.fadeDuration, generation: generation) else { return }
                    }
                    guard generation == self.transitionGeneration else { return }
                    let newPlayback = try await self.makePlayback(group: .songs, index: index, fileName: fileName, volume: 1, loops: 0)
                    guard generation == self.transitionGeneration else {
                        self.stopImmediately(newPlayback)
                        return
                    }
                }
                self.statusMessage = nil
                self.refreshPlaybackState()
            } catch {
                self.statusMessage = "Could not play this audio file: \(error.localizedDescription)"
            }
        }
    }

    func toggleCurrentSongPlayback() {
        guard let player = currentSongPlayer else { return }
        if player.isPlaying {
            player.pause()
            refreshPlaybackState()
        } else {
            let preparedPlayer = PreparedAudioPlayer(player: player)
            Task { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        _ = preparedPlayer.player.play()
                        continuation.resume()
                    }
                }
                self.refreshPlaybackState()
            }
        }
    }

    func seekCurrentSong(to time: TimeInterval) {
        guard let player = currentSongPlayer else { return }
        player.currentTime = min(max(0, time), player.duration)
        refreshSongProgress()
    }

    func skipCurrentSong(by seconds: TimeInterval) {
        guard let player = currentSongPlayer else { return }
        seekCurrentSong(to: player.currentTime + seconds)
    }

    private var currentSongPlayer: AVAudioPlayer? {
        guard let currentSongID else { return nil }
        return players[PlaybackKey(group: .songs, slotID: currentSongID)]?.player
    }

    private func startSongProgressUpdates() {
        songProgressTask?.cancel()
        songProgressTask = Task { @MainActor in
            while !Task.isCancelled {
                self.refreshSongProgress()
                do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            }
        }
    }

    private func refreshSongProgress() {
        guard let player = currentSongPlayer else {
            currentSongLabel = nil
            songElapsedTime = 0
            songDuration = 0
            isCurrentSongPlaying = false
            songProgressTask?.cancel()
            songProgressTask = nil
            return
        }
        songElapsedTime = player.currentTime
        songDuration = player.duration
        isCurrentSongPlaying = player.isPlaying
        if let slot = songs.first(where: { $0.id == currentSongID }) {
            currentSongLabel = slot.label
        }
    }

    func playLoop(at index: Int) {
        guard loops.indices.contains(index), let fileName = loops[index].storedFileName else { return }
        let key = PlaybackKey(group: .loops, slotID: loops[index].id)
        if let existing = players[key] {
            let generation = beginTransition()
            transitionTask = Task { @MainActor in
                await self.fadeOut([existing], duration: self.fadeDuration, generation: generation)
            }
            return
        }

        let generation = beginTransition()
        loopTransitionInProgress = true
        let previous = Array(players.values)
        transitionTask = Task { @MainActor in
            do {
                try await self.activateAudioSession()
            } catch {
                self.loopTransitionInProgress = false
                self.statusMessage = "Audio output could not be activated: \(error.localizedDescription)"
                return
            }
            guard generation == self.transitionGeneration else { return }
            guard await self.fadeOut(previous, duration: self.fadeDuration, generation: generation) else { return }
            guard generation == self.transitionGeneration else { return }
            do {
                let playback = try await self.makePlayback(group: .loops, index: index, fileName: fileName, volume: 1, loops: -1)
                guard generation == self.transitionGeneration else {
                    self.stopImmediately(playback)
                    self.loopTransitionInProgress = false
                    return
                }
                self.loopTransitionInProgress = false
                self.statusMessage = nil
                self.refreshPlaybackState()
            } catch {
                self.loopTransitionInProgress = false
                self.statusMessage = "Could not play this loop: \(error.localizedDescription)"
            }
        }
    }

    func togglePad(at index: Int) {
        guard pads.indices.contains(index), let fileName = pads[index].storedFileName else { return }
        guard playingLoopIndex == nil, !loopTransitionInProgress else {
            statusMessage = "Fade out the service loop before playing a pad."
            return
        }
        let key = PlaybackKey(group: .pads, slotID: pads[index].id)
        if let existing = players[key] {
            padTransitionGeneration += 1
            fadeOutIndependently(existing, duration: fadeDuration)
        } else {
            padTransitionGeneration += 1
            let generation = padTransitionGeneration
            let padFadeDuration = fadeDuration
            let previousPads = activePlayers(for: .pads)
            previousPads.forEach { fadeOutIndependently($0, duration: padFadeDuration) }
            Task { @MainActor in
                do {
                    try await self.activateAudioSession()
                    if !previousPads.isEmpty {
                        try await Task.sleep(nanoseconds: UInt64(padFadeDuration * 1_000_000_000))
                    }
                    guard generation == self.padTransitionGeneration else { return }
                    guard self.playingLoopIndex == nil, !self.loopTransitionInProgress else {
                        self.statusMessage = "Fade out the service loop before playing a pad."
                        return
                    }
                    guard self.activePlayers(for: .pads).isEmpty else { return }
                    guard self.players[key] == nil else { return }
                    let playback = try await self.makePlayback(group: .pads, index: index, fileName: fileName, volume: 1, loops: -1)
                    guard generation == self.padTransitionGeneration,
                          self.playingLoopIndex == nil,
                          !self.loopTransitionInProgress else {
                        self.stopImmediately(playback)
                        return
                    }
                    self.statusMessage = nil
                } catch {
                    self.statusMessage = "Could not play this pad: \(error.localizedDescription)"
                }
            }
        }
    }

    func fadeOutEverything() {
        guard !players.isEmpty else { return }
        let generation = beginTransition()
        loopTransitionInProgress = false
        let active = Array(players.values)
        transitionTask = Task { @MainActor in
            guard await self.fadeOut(active, duration: self.fadeDuration, generation: generation) else { return }
            self.refreshPlaybackState()
        }
    }

    func stopAllAudioImmediately() {
        _ = beginTransition()
        padTransitionGeneration += 1
        loopTransitionInProgress = false
        songProgressTask?.cancel()
        songProgressTask = nil

        let active = Array(players.values)
        for playback in active {
            let player = PreparedAudioPlayer(player: playback.player)
            DispatchQueue.global(qos: .userInitiated).async {
                player.player.stop()
            }
            playback.player.delegate = nil
        }
        players.removeAll()
        currentSongID = nil
        refreshPlaybackState()
    }

    private func beginTransition() -> Int {
        transitionTask?.cancel()
        transitionGeneration += 1
        return transitionGeneration
    }

    private func activePlayers(for group: AudioGroup) -> [ActivePlayback] {
        players.values.filter { $0.key.group == group }
    }

    private func makePlayback(group: AudioGroup, index: Int, fileName: String, volume: Float, loops loopCount: Int) async throws -> ActivePlayback {
        let slot = slots(for: group)[index]
        let key = PlaybackKey(group: group, slotID: slot.id)
        let url = libraryDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "WorshipAudio",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "The saved audio file for \(slot.label) is missing from this service. Import it again."]
            )
        }
        let prepared = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PreparedAudioPlayer, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.numberOfLoops = loopCount
                    player.volume = volume
                    guard player.prepareToPlay(), player.play() else {
                        throw NSError(domain: "WorshipAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "The audio player could not start."])
                    }
                    continuation.resume(returning: PreparedAudioPlayer(player: player))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        let player = prepared.player
        player.delegate = self
        let active = ActivePlayback(key: key, player: player)
        players[key] = active
        if group == .songs { currentSongID = slot.id }
        refreshPlaybackState()
        if group == .songs { startSongProgressUpdates() }
        return active
    }

    private func crossfade(_ outgoing: [ActivePlayback], into incoming: ActivePlayback, duration: TimeInterval, generation: Int) async {
        let steps = max(1, Int(duration * 20))
        let initialVolumes = outgoing.map(\.player.volume)
        for step in 1...steps {
            guard generation == transitionGeneration, !Task.isCancelled else { return }
            let progress = Float(step) / Float(steps)
            for (offset, playback) in outgoing.enumerated() {
                playback.player.volume = initialVolumes[offset] * (1 - progress)
            }
            incoming.player.volume = progress
            do { try await Task.sleep(nanoseconds: 50_000_000) } catch { return }
        }
        guard generation == transitionGeneration else { return }
        outgoing.forEach(stopImmediately)
    }

    @discardableResult
    private func fadeOut(_ fading: [ActivePlayback], duration: TimeInterval, generation: Int) async -> Bool {
        guard !fading.isEmpty else { return generation == transitionGeneration }
        let initialVolumes = fading.map(\.player.volume)
        let steps = max(1, Int(duration * 20))
        for step in 1...steps {
            guard generation == transitionGeneration, !Task.isCancelled else { return false }
            let progress = Float(step) / Float(steps)
            for (offset, playback) in fading.enumerated() {
                playback.player.volume = initialVolumes[offset] * (1 - progress)
            }
            do { try await Task.sleep(nanoseconds: 50_000_000) } catch { return false }
        }
        guard generation == transitionGeneration else { return false }
        fading.forEach(stopImmediately)
        return true
    }

    private func stopImmediately(_ playback: ActivePlayback) {
        let player = PreparedAudioPlayer(player: playback.player)
        DispatchQueue.global(qos: .userInitiated).async {
            player.player.stop()
        }
        playback.player.delegate = nil
        players.removeValue(forKey: playback.key)
        if currentSongID == playback.key.slotID { currentSongID = nil }
        refreshPlaybackState()
    }

    private func stopPlayback(for group: AudioGroup, slotID: UUID) {
        let key = PlaybackKey(group: group, slotID: slotID)
        if let active = players[key] { stopImmediately(active) }
    }

    private func fadeOutIndependently(_ playback: ActivePlayback, duration: TimeInterval) {
        playback.player.setVolume(0, fadeDuration: duration)
        Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) } catch { return }
            guard self.players[playback.key] === playback else { return }
            self.stopImmediately(playback)
        }
    }

    private func orderedSongIndices() -> [Int] {
        flowOrder.flatMap(\.songSlotIDs).compactMap { id in songs.firstIndex(where: { $0.id == id }) }
    }

    private func nextLoadedSong(after finishedID: UUID) -> Int? {
        let order = orderedSongIndices()
        guard let currentIndex = songs.firstIndex(where: { $0.id == finishedID }),
              let position = order.firstIndex(of: currentIndex) else { return nil }
        return order.dropFirst(position + 1).first(where: { songs[$0].isLoaded })
    }

    private func refreshPlaybackState() {
        playingSongIndices = Set(songs.indices.filter { index in
            players[PlaybackKey(group: .songs, slotID: songs[index].id)] != nil
        })
        playingLoopIndex = loops.indices.first(where: { index in
            players[PlaybackKey(group: .loops, slotID: loops[index].id)] != nil
        })
        playingPadIndices = Set(pads.indices.filter { index in
            players[PlaybackKey(group: .pads, slotID: pads[index].id)] != nil
        })

        if let loopIndex = playingLoopIndex {
            nowPlaying = loops[loopIndex].label
        } else if let currentSongID, let index = songs.firstIndex(where: { $0.id == currentSongID }), playingSongIndices.contains(index) {
            nowPlaying = songs[index].label
        } else if !playingSongIndices.isEmpty {
            nowPlaying = songs[playingSongIndices.sorted().last ?? 0].label
        } else if !playingPadIndices.isEmpty {
            nowPlaying = "\(playingPadIndices.count) pad\(playingPadIndices.count == 1 ? "" : "s") playing"
        } else {
            nowPlaying = "Nothing playing"
        }
        refreshSongProgress()
    }
}

extension AudioLibrary: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self,
                  let entry = self.players.values.first(where: { $0.player === player }) else { return }
            let group = entry.key.group
            let finishedID = entry.key.slotID
            let wasCurrentSong = self.currentSongID == finishedID
            self.stopImmediately(entry)
            if group == .songs, wasCurrentSong, self.playbackMode == .continuous,
               let next = self.nextLoadedSong(after: finishedID) {
                self.playSong(at: next)
            }
            self.refreshPlaybackState()
        }
    }
}
