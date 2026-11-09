import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct SlotEditorView: View {
    let group: AudioGroup
    let index: Int
    let current: AudioSlot
    let keyName: String?
    let onSave: (String, URL?, String?) throws -> Void
    let onDelete: () throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var selectedFile: URL?
    @State private var importedSourceFileName: String?
    @State private var isImporting = false
    @State private var isStagingImportedFile = false
    @State private var showingDriveImport = false
    @State private var downloadedStagingFile: URL?
    @State private var errorMessage: String?

    init(
        group: AudioGroup,
        index: Int,
        current: AudioSlot,
        keyName: String?,
        onSave: @escaping (String, URL?, String?) throws -> Void,
        onDelete: @escaping () throws -> Void
    ) {
        self.group = group
        self.index = index
        self.current = current
        self.keyName = keyName
        self.onSave = onSave
        self.onDelete = onDelete
        _label = State(initialValue: current.label)
    }

    private var title: String {
        switch group {
        case .songs: current.isLoaded ? "Edit song" : "Add song"
        case .loops: current.isLoaded ? "Edit loop" : "Add loop"
        case .pads: "\(keyName ?? current.label) pad"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Button label") {
                    TextField("Give this audio a label", text: $label)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section("Audio file") {
                    Button {
                        isImporting = true
                    } label: {
                        Label(importedSourceFileName ?? current.originalFileName ?? selectedFile?.lastPathComponent ?? "Choose from Files", systemImage: "folder")
                            .lineLimit(1)
                    }
                    if selectedFile != nil || current.isLoaded {
                        Text(importedSourceFileName ?? current.originalFileName ?? selectedFile?.lastPathComponent ?? "Audio is stored on this device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if downloadedStagingFile != nil {
                        Label("Downloaded to this device. Tap Save to add it to this service.", systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                    if isStagingImportedFile {
                        Label("Downloading and saving a local copy…", systemImage: "arrow.down.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("Choose a file from On My iPhone/iPad or use Browse > Locations > Google Drive. The selected file is downloaded into this app for offline playback.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        showingDriveImport = true
                    } label: {
                        Label("Import from Google Drive link", systemImage: "link")
                    }
                    Text("Paste a Drive link that is available to anyone with the link. The audio is downloaded and saved on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if current.isLoaded {
                    Section {
                        Button("Remove audio", role: .destructive) {
                            do {
                                try onDelete()
                                discardDownloadedFile()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        discardDownloadedFile()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try onSave(label, selectedFile, importedSourceFileName)
                            discardDownloadedFile()
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(isStagingImportedFile || (!current.isLoaded && selectedFile == nil))
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let sourceURL = urls.first else { return }
                    let sourceName = sourceURL.lastPathComponent
                    importedSourceFileName = sourceName
                    let suggestedLabel = URL(fileURLWithPath: sourceName).deletingPathExtension().lastPathComponent
                    if !suggestedLabel.isEmpty { label = suggestedLabel }
                    isStagingImportedFile = true
                    Task { @MainActor in
                        do {
                            let stagedURL = try await Task.detached(priority: .userInitiated) {
                                try AudioFileImportStager.copyToAppStorage(from: sourceURL)
                            }.value
                            discardDownloadedFile()
                            selectedFile = stagedURL
                            downloadedStagingFile = stagedURL
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isStagingImportedFile = false
                    }
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showingDriveImport) {
                GoogleDriveLinkImportSheet { fileURL, sourceName in
                    selectedFile = fileURL
                    downloadedStagingFile = fileURL
                    importedSourceFileName = sourceName
                    let suggestedLabel = URL(fileURLWithPath: sourceName).deletingPathExtension().lastPathComponent
                    if !suggestedLabel.isEmpty { label = suggestedLabel }
                }
            }
            .alert("Couldn’t save audio", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Try choosing the file again.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func discardDownloadedFile() {
        if let downloadedStagingFile {
            try? FileManager.default.removeItem(at: downloadedStagingFile)
        }
        downloadedStagingFile = nil
    }
}

private enum AudioFileImportStager {
    static func copyToAppStorage(from sourceURL: URL) throws -> URL {
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw AudioFileImportError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let fileManager = FileManager.default
        let stagingDirectory = WorshipStorage.rootDirectory.appendingPathComponent("PendingImports", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension
        let destinationURL = stagingDirectory
            .appendingPathComponent("OnCue-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try fileManager.copyItem(at: coordinatedURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }

        let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard fileManager.fileExists(atPath: destinationURL.path), size > 0 else {
            try? fileManager.removeItem(at: destinationURL)
            throw AudioFileImportError.emptyFile
        }
        return destinationURL
    }
}

private enum AudioFileImportError: LocalizedError {
    case accessDenied
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "The selected file could not be accessed. In Files, make sure Google Drive is enabled under Browse and try selecting the song again."
        case .emptyFile:
            return "The selected file downloaded as an empty file. Check that it is available in Google Drive, then try again."
        }
    }
}

private struct GoogleDriveLinkImportSheet: View {
    let onDownloaded: (URL, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var isDownloading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Google Drive file") {
                    TextField("Paste the Drive share link", text: $link, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .lineLimit(2...4)
                    Text("The link must point to an audio file that can be downloaded without signing in. Private files can still be selected from Files if Google Drive is available there.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if isDownloading {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Downloading audio…")
                        }
                    }
                }
            }
            .navigationTitle("Google Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDownloading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") { Task { await download() } }
                        .disabled(isDownloading || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Couldn’t import from Google Drive", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Check the link and try again.")
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func download() async {
        isDownloading = true
        defer { isDownloading = false }

        do {
            guard let fileID = driveFileID(from: link) else {
                throw DriveImportError.invalidLink
            }
            var components = URLComponents(string: "https://drive.google.com/uc")!
            components.queryItems = [
                URLQueryItem(name: "export", value: "download"),
                URLQueryItem(name: "id", value: fileID)
            ]
            guard let downloadURL = components.url else { throw DriveImportError.invalidLink }
            let (downloadURLOnDisk, response) = try await URLSession.shared.download(from: downloadURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw DriveImportError.downloadFailed
            }

            let suggestedName = response.suggestedFilename ?? "audio"
            let suggestedExtension = URL(fileURLWithPath: suggestedName).pathExtension.lowercased()
            let mimeType = response.mimeType?.lowercased() ?? ""
            let mimeExtension = UTType(mimeType: mimeType)?.preferredFilenameExtension
            let fileExtension = suggestedExtension.isEmpty ? (mimeExtension ?? "") : suggestedExtension
            let supportedExtensions: Set<String> = ["mp3", "wav", "m4a", "aac", "aif", "aiff", "caf", "flac", "ogg", "opus"]
            guard !mimeType.contains("text/html"),
                  (supportedExtensions.contains(fileExtension) || UTType(mimeType: mimeType)?.conforms(to: .audio) == true) else {
                throw DriveImportError.notAudio
            }

            let stagingDirectory = WorshipStorage.rootDirectory.appendingPathComponent("PendingImports", isDirectory: true)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            let stagedURL = stagingDirectory
                .appendingPathComponent("OnCue-\(UUID().uuidString)")
                .appendingPathExtension(fileExtension.isEmpty ? "audio" : fileExtension)
            try FileManager.default.copyItem(at: downloadURLOnDisk, to: stagedURL)
            let stagedAttributes = try FileManager.default.attributesOfItem(atPath: stagedURL.path)
            let stagedFileSize = (stagedAttributes[.size] as? NSNumber)?.intValue ?? 0
            guard FileManager.default.fileExists(atPath: stagedURL.path), stagedFileSize > 0 else {
                try? FileManager.default.removeItem(at: stagedURL)
                throw DriveImportError.downloadFailed
            }
            onDownloaded(stagedURL, URL(fileURLWithPath: suggestedName).lastPathComponent)
            dismiss()
        } catch let error as DriveImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "The file could not be downloaded. Check that the link is public, the file allows downloads, and the device is connected to the internet."
        }
    }

    private func driveFileID(from input: String) -> String? {
        guard let components = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased(),
              host == "drive.google.com" || host == "docs.google.com" else { return nil }
        let queryID = components.queryItems?.first(where: { $0.name == "id" })?.value
        let pathParts = components.path.split(separator: "/").map(String.init)
        let pathID: String? = {
            guard let index = pathParts.firstIndex(of: "d"), pathParts.indices.contains(index + 1) else { return nil }
            return pathParts[index + 1]
        }()
        guard let id = queryID ?? pathID,
              id.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { return nil }
        return id
    }
}

private enum DriveImportError: LocalizedError {
    case invalidLink
    case downloadFailed
    case notAudio

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "Paste a Google Drive file link such as drive.google.com/file/d/…/view."
        case .downloadFailed:
            return "Google Drive could not provide this file. Check its sharing and download permissions."
        case .notAudio:
            return "Google Drive returned a page or a file type that doesn’t appear to be audio. Check the link and try again."
        }
    }
}
