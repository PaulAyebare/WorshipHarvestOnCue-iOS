import Foundation

enum AudioGroup: String, CaseIterable, Identifiable, Codable {
    case songs
    case loops
    case pads

    var id: String { rawValue }
}

enum SongPlaybackMode: String, CaseIterable, Identifiable, Codable {
    case crossfade
    case continuous
    case individual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crossfade: return "Crossfade"
        case .continuous: return "Continuous"
        case .individual: return "Individual"
        }
    }
}

enum FlowSegment: String, CaseIterable, Identifiable, Codable {
    case preService
    case highPraise
    case exhortationPrayer
    case adoration
    case serviceHost
    case servingMoment
    case danceTeam
    case givingExhortation
    case specialSong
    case welcomeSpeaker
    case responseMinistry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preService: return "Pre-service"
        case .highPraise: return "High Praise"
        case .exhortationPrayer: return "Exhortation and Prayer"
        case .adoration: return "Adoration"
        case .serviceHost: return "Service Host"
        case .servingMoment: return "Serving Moment / Testimony Time"
        case .danceTeam: return "Dance Team"
        case .givingExhortation: return "Giving Exhortation"
        case .specialSong: return "Special Song"
        case .welcomeSpeaker: return "Welcome the Speaker"
        case .responseMinistry: return "Response / Ministry Moment"
        }
    }

    var subtitle: String {
        switch self {
        case .preService: return "Ambient music · repeats until stopped"
        case .highPraise: return "Four song slots"
        case .exhortationPrayer: return "Prayer ambience · repeats until stopped"
        case .adoration: return "Three song slots"
        case .serviceHost: return "Background loop · repeats until stopped"
        case .servingMoment: return "Background loop · repeats until stopped"
        case .danceTeam: return "Dance track · plays once"
        case .givingExhortation: return "Background loop · repeats until stopped"
        case .specialSong: return "Song slot · plays once"
        case .welcomeSpeaker: return "Background loop · repeats until stopped"
        case .responseMinistry: return "A repeating loop and three song slots"
        }
    }

    var symbol: String {
        switch self {
        case .preService: return "waveform"
        case .highPraise: return "music.note.list"
        case .exhortationPrayer: return "hands.sparkles"
        case .adoration: return "music.note"
        case .serviceHost: return "person.wave.2"
        case .servingMoment: return "heart.text.square"
        case .danceTeam: return "figure.dance"
        case .givingExhortation: return "gift"
        case .specialSong: return "music.mic"
        case .welcomeSpeaker: return "mic"
        case .responseMinistry: return "sparkles"
        }
    }

    var songRange: Range<Int>? {
        switch self {
        case .highPraise: return 0..<4
        case .adoration: return 4..<7
        case .danceTeam: return 7..<8
        case .specialSong: return 8..<9
        case .responseMinistry: return 9..<12
        default: return nil
        }
    }

    var loopIndex: Int? {
        switch self {
        case .preService: return 0
        case .exhortationPrayer: return 1
        case .serviceHost: return 2
        case .servingMoment: return 3
        case .givingExhortation: return 4
        case .welcomeSpeaker: return 5
        case .responseMinistry: return 6
        default: return nil
        }
    }
}

enum ServiceSectionKind: String, CaseIterable, Identifiable, Codable {
    case loop, songs, specialMusic, responseMinistry
    var id: String { rawValue }
    var title: String {
        switch self {
        case .loop: return "Loop"
        case .songs: return "Songs"
        case .specialMusic: return "Special music"
        case .responseMinistry: return "Response / Ministry Moment"
        }
    }
}

struct ServiceSection: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var kind: ServiceSectionKind
    var songSlotIDs: [UUID] = []
    var loopSlotID: UUID?
    var isBuiltIn: Bool = false

    var subtitle: String {
        switch kind {
        case .loop: return "Background audio · repeats until stopped"
        case .songs: return "\(songSlotIDs.count) song slot\(songSlotIDs.count == 1 ? "" : "s")"
        case .specialMusic: return "Special music · plays once"
        case .responseMinistry: return "Repeating loop and \(songSlotIDs.count) song slots"
        }
    }

    var symbol: String {
        switch kind {
        case .loop: return "waveform"
        case .songs: return "music.note.list"
        case .specialMusic: return "music.mic"
        case .responseMinistry: return "sparkles"
        }
    }
}

struct AudioSlot: Codable, Identifiable {
    var id = UUID()
    var label: String
    var originalFileName: String?
    var storedFileName: String?

    var isLoaded: Bool { storedFileName != nil }
}

struct AudioLibraryState: Codable {
    var schemaVersion: Int
    var songs: [AudioSlot]
    var loops: [AudioSlot]
    var pads: [AudioSlot]
    var flowOrder: [FlowSegment]
    var notes: String
    var sections: [ServiceSection]?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case songs
        case loops
        case pads
        case flowOrder
        case notes
        case sections
    }

    init(
        schemaVersion: Int = 3,
        songs: [AudioSlot],
        loops: [AudioSlot],
        pads: [AudioSlot],
        flowOrder: [FlowSegment] = FlowSegment.allCases,
        notes: String = "",
        sections: [ServiceSection]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.songs = songs
        self.loops = loops
        self.pads = pads
        self.flowOrder = flowOrder
        self.notes = notes
        self.sections = sections
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        songs = try values.decodeIfPresent([AudioSlot].self, forKey: .songs) ?? []
        loops = try values.decodeIfPresent([AudioSlot].self, forKey: .loops) ?? []
        pads = try values.decodeIfPresent([AudioSlot].self, forKey: .pads) ?? []
        flowOrder = try values.decodeIfPresent([FlowSegment].self, forKey: .flowOrder) ?? FlowSegment.allCases
        notes = try values.decodeIfPresent(String.self, forKey: .notes) ?? ""
        sections = try values.decodeIfPresent([ServiceSection].self, forKey: .sections)
    }
}
