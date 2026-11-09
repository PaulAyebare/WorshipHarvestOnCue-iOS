import SwiftUI

private struct EditingSlot: Identifiable {
    let group: AudioGroup
    let index: Int
    let keyName: String?
    var id: String { "\(group.rawValue)-\(index)" }
}

struct ContentView: View {
    @StateObject private var serviceStore = ServiceStore()
    @State private var showingCreateService = false
    @State private var serviceToEdit: WorshipService?
    @State private var serviceToDelete: WorshipService?
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.025, green: 0.045, blue: 0.09).ignoresSafeArea()
                List {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image("OnCueMark")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("WORSHIP TEAM SERVICE FLOW")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .tracking(1.5)
                                    .foregroundStyle(.white.opacity(0.58))
                                Text("Worship Harvest OnCue")
                                    .font(.system(size: 23, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        Text("Your upcoming services")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Create a service, arrange its flow, and keep its audio and notes on this device.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.62))
                        HStack {
                            Label("\(serviceStore.services.count) of \(ServiceStore.maximumServices) services", systemImage: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(red: 0.63, green: 0.86, blue: 0.82))
                            Spacer()
                            Button {
                                showingCreateService = true
                            } label: {
                                Label("New service", systemImage: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(Color.amber, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!serviceStore.canCreateService)
                            .opacity(serviceStore.canCreateService ? 1 : 0.45)
                        }
                    }
                    .padding(16)
                    .background(
                        LinearGradient(colors: [Color(red: 0.08, green: 0.17, blue: 0.28), Color(red: 0.06, green: 0.10, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .listRowStyle()

                    if serviceStore.services.isEmpty {
                        VStack(spacing: 9) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 27, weight: .medium))
                                .foregroundStyle(Color.amber)
                            Text("No services yet")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Text("Tap New service to add a name and date.")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 38)
                        .listRowStyle()
                    } else {
                        ForEach(serviceStore.services.sorted { $0.date < $1.date }) { service in
                            serviceRow(service)
                                .listRowStyle()
                        }
                    }

                    if let status = serviceStore.statusMessage {
                        Label(status, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .padding(14)
                            .listRowStyle()
                    }

                    Text("Audio, service order, and notes are stored separately for each service.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .padding(.vertical, 8)
                        .listRowStyle()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateService = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!serviceStore.canCreateService)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.amber)
        .sheet(isPresented: $showingCreateService) {
            CreateServiceSheet(serviceStore: serviceStore)
        }
        .sheet(item: $serviceToEdit) { service in
            EditServiceSheet(serviceStore: serviceStore, service: service)
        }
        .confirmationDialog(
            "Delete this service?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: serviceToDelete
        ) { service in
            Button("Delete service and all its audio", role: .destructive) {
                do {
                    try serviceStore.deleteService(id: service.id)
                } catch {
                    errorMessage = error.localizedDescription
                }
                serviceToDelete = nil
            }
            Button("Cancel", role: .cancel) { serviceToDelete = nil }
        } message: { service in
            Text("\(service.name), its imported audio files, service order, and notes will be permanently deleted from this device.")
        }
        .alert("Could not update services", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder
    private func serviceRow(_ service: WorshipService) -> some View {
        HStack(alignment: .top, spacing: 0) {
            NavigationLink {
                ServiceWorkspaceView(service: service)
            } label: {
                HStack(spacing: 13) {
                    VStack(spacing: 2) {
                        Text(service.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.7)
                        Text(service.date.formatted(.dateTime.day()))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.amber)
                    .frame(width: 55, height: 57)
                    .background(Color.amber.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(service.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(service.date.formatted(date: .complete, time: .shortened))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit service", systemImage: "pencil") {
                    serviceToEdit = service
                }
                Button("Duplicate service", systemImage: "plus.square.on.square") {
                    do {
                        _ = try serviceStore.duplicateService(id: service.id)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .disabled(!serviceStore.canCreateService)
                Button("Delete service", systemImage: "trash", role: .destructive) {
                    serviceToDelete = service
                    showingDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Edit or delete \(service.name)")
            .padding(.top, 7)
            .padding(.trailing, 7)
        }
        .background(Color(red: 0.065, green: 0.09, blue: 0.145), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.075), lineWidth: 1))
    }
}

private struct CreateServiceSheet: View {
    @ObservedObject var serviceStore: ServiceStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var serviceDate = Calendar.current.nextDate(after: Date(), matching: DateComponents(weekday: 1), matchingPolicy: .nextTime) ?? Date()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Service details") {
                    TextField("Service name", text: $name)
                        .textInputAutocapitalization(.words)
                    DatePicker("Date and time", selection: $serviceDate, in: Calendar.current.startOfDay(for: Date())...Date.distantFuture, displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    Text("\(serviceStore.services.count) of \(ServiceStore.maximumServices) services are currently saved. Each service keeps its own audio files and notes on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !serviceStore.canCreateService)
                }
            }
            .alert("Could not create service", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func create() {
        do {
            _ = try serviceStore.createService(name: name, date: serviceDate)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditServiceSheet: View {
    @ObservedObject var serviceStore: ServiceStore
    @Environment(\.dismiss) private var dismiss
    let service: WorshipService
    @State private var name: String
    @State private var serviceDate: Date
    @State private var errorMessage: String?

    init(serviceStore: ServiceStore, service: WorshipService) {
        self.serviceStore = serviceStore
        self.service = service
        _name = State(initialValue: service.name)
        _serviceDate = State(initialValue: service.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service details") {
                    TextField("Service name", text: $name)
                        .textInputAutocapitalization(.words)
                    DatePicker("Date and time", selection: $serviceDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Edit service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Could not update service", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        do {
            try serviceStore.updateService(id: service.id, name: name, date: serviceDate)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ServiceWorkspaceView: View {
    let service: WorshipService
    @StateObject private var audio: AudioLibrary
    @State private var editingSlot: EditingSlot?
    @State private var editMode: EditMode = .inactive
    @State private var showingAddSection = false
    @State private var sectionToRename: ServiceSection?
    @State private var sectionToDelete: ServiceSection?
    @State private var showingSectionDeleteConfirmation = false
    @FocusState private var notesFocused: Bool

    private let padLabels = ["C", "C♯\nD♭", "D", "D♯\nE♭", "E", "F", "F♯\nG♭", "G", "G♯\nA♭", "A", "A♯\nB♭", "B"]
    private let padNames = ["C", "C♯ / D♭", "D", "D♯ / E♭", "E", "F", "F♯ / G♭", "G", "G♯ / A♭", "A", "A♯ / B♭", "B"]
    private let padColumns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 6)

    init(service: WorshipService) {
        self.service = service
        _audio = StateObject(wrappedValue: AudioLibrary(serviceID: service.id))
    }

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.045, blue: 0.09).ignoresSafeArea()
            List {
                    header
                        .listRowStyle()

                    ForEach(audio.flowOrder) { segment in
                        FlowSegmentCard(segment: segment, audio: audio, onEdit: { group, index, keyName in
                            editSlot(group, index, keyName)
                        }, onRename: { sectionToRename = segment }, onDelete: {
                            sectionToDelete = segment
                            showingSectionDeleteConfirmation = true
                        })
                            .listRowStyle()
                    }
                    .onMove(perform: audio.moveFlowSegments)

                    Button { showingAddSection = true } label: {
                        Label("Add service section", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.amber, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                        .listRowStyle()

                    padSection
                        .listRowStyle()

                    playbackControls
                        .listRowStyle()

                    notesSection
                        .listRowStyle()

                    if let message = audio.statusMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            .listRowStyle()
                    }

                    footer
                        .listRowStyle()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .environment(\.editMode, $editMode)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let title = audio.currentSongLabel {
                miniPlayer(title: title)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(service.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            audio.stopAllAudioImmediately()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { notesFocused = false }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color(red: 1.0, green: 0.72, blue: 0.34))
        .sheet(item: $editingSlot) { target in
            SlotEditorView(
                group: target.group,
                index: target.index,
                current: audio.slot(for: target.group, at: target.index),
                keyName: target.keyName,
                onSave: { label, file, originalFileName in
                    try audio.updateSlot(group: target.group, index: target.index, label: label, importedFile: file, originalFileName: originalFileName)
                },
                onDelete: { try audio.removeSlot(group: target.group, index: target.index) }
            )
        }
        .sheet(isPresented: $showingAddSection) {
            AddServiceSectionSheet { name, kind, count in
                audio.addSection(name: name, kind: kind, songCount: count)
            }
        }
        .sheet(item: $sectionToRename) { section in
            EditServiceSectionSheet(section: section) { title, count in
                audio.renameSection(id: section.id, title: title)
                audio.resizeSongSlots(sectionID: section.id, count: count)
            }
        }
        .confirmationDialog("Delete this section and its audio?", isPresented: $showingSectionDeleteConfirmation, titleVisibility: .visible, presenting: sectionToDelete) { section in
            Button("Delete section and audio", role: .destructive) { audio.removeSection(id: section.id) }
            Button("Cancel", role: .cancel) {}
        } message: { section in
            Text("\(section.title), its audio slots, and imported audio files will be removed from this service.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image("OnCueMark")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("WORSHIP TEAM SERVICE FLOW")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.58))
                    Text("Worship Harvest OnCue")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                Label("Offline", systemImage: "checkmark.icloud")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.63, green: 0.86, blue: 0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                    Text(service.date.formatted(date: .complete, time: .shortened) + " · Tap an empty tile to add audio. Use Edit to reorder sections.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }

            HStack(spacing: 8) {
                Circle().fill(Color(red: 1.0, green: 0.72, blue: 0.34)).frame(width: 7, height: 7)
                Text("\(audio.nowPlaying)")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text("\(audio.notes.count)/600 notes")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
        }
        .padding(15)
        .background(
            LinearGradient(colors: [Color(red: 0.08, green: 0.17, blue: 0.28), Color(red: 0.06, green: 0.10, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var playbackControls: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Song playback", subtitle: "Applies to songs throughout the service", symbol: "waveform.path", tint: .amber)

            Picker("Song playback mode", selection: $audio.playbackMode) {
                ForEach(SongPlaybackMode.allCases) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 7) {
                Text("Fade")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                ForEach([2.0, 4.0, 6.0], id: \.self) { duration in
                    Button {
                        audio.fadeDuration = duration
                    } label: {
                        Text("\(Int(duration)) sec")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(audio.fadeDuration == duration ? .black : .white.opacity(0.8))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(audio.fadeDuration == duration ? Color.amber : Color.white.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 2)
                Button { audio.fadeOutEverything() } label: {
                    Label("Fade out", systemImage: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(red: 0.56, green: 0.19, blue: 0.19), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .flowCard()
    }

    private func miniPlayer(title: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .foregroundStyle(Color.amber)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("SONG PLAYER")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.42))
            }

            HStack(spacing: 10) {
                Text(audio.songElapsedTime.playerTime)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 37, alignment: .leading)
                Slider(value: Binding(
                    get: { audio.songElapsedTime },
                    set: { audio.seekCurrentSong(to: $0) }
                ), in: 0...max(audio.songDuration, 0.01))
                .tint(Color.amber)
                .disabled(audio.songDuration <= 0)
                Text(audio.songDuration.playerTime)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(width: 37, alignment: .trailing)
            }

            HStack(spacing: 28) {
                Button { audio.skipCurrentSong(by: -15) } label: {
                    Image(systemName: "gobackward.15")
                }
                Button { audio.toggleCurrentSongPlayback() } label: {
                    Image(systemName: audio.isCurrentSongPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 34)
                        .background(Color.amber, in: Capsule())
                }
                Button { audio.skipCurrentSong(by: 15) } label: {
                    Image(systemName: "goforward.15")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .buttonStyle(.plain)
            .accessibilityLabel("Song playback controls")
        }
        .padding(.horizontal, 16)
        .padding(.top, 11)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.amber.opacity(0.45)).frame(height: 1)
        }
        .animation(.easeOut(duration: 0.2), value: audio.currentSongLabel)
    }

    private var padSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Key pads", subtitle: "Play with a song, or on their own", symbol: "pianokeys", tint: Color(red: 0.60, green: 0.79, blue: 1.0))
            LazyVGrid(columns: padColumns, spacing: 7) {
                ForEach(padNames.indices, id: \.self) { index in
                    let slot = audio.pads[index]
                    Button {
                        if slot.isLoaded { audio.togglePad(at: index) }
                        else { editSlot(.pads, index, padNames[index]) }
                    } label: {
                        VStack(spacing: 5) {
                            Text(padLabels[index])
                                .font(.system(size: padLabels[index].contains("\n") ? 9 : 13, weight: .bold, design: .rounded))
                                .lineSpacing(-1)
                                .multilineTextAlignment(.center)
                            Circle()
                                .fill(audio.playingPadIndices.contains(index) ? Color(red: 0.60, green: 0.79, blue: 1.0) : (slot.isLoaded ? .white.opacity(0.45) : .clear))
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(audio.playingPadIndices.contains(index) ? Color.blue.opacity(0.2) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(slot.isLoaded ? 0.14 : 0.08), style: StrokeStyle(lineWidth: 1, dash: slot.isLoaded ? [] : [4, 3])))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit \(padNames[index]) pad", systemImage: "pencil") { editSlot(.pads, index, padNames[index]) }
                    }
                    .accessibilityLabel("\(padNames[index]) pad, \(slot.isLoaded ? slot.label : "add audio")")
                }
            }
        }
        .flowCard()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Service notes", subtitle: "Saved on this device · 600 characters maximum", symbol: "note.text", tint: .amber)
            ZStack(alignment: .topLeading) {
                if audio.notes.isEmpty {
                    Text("Add cues, reminders, or details for the team…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 9)
                }
                TextEditor(text: Binding(get: { audio.notes }, set: { audio.setNotes($0) }))
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 105, maxHeight: 160)
                    .focused($notesFocused)
                    .accessibilityLabel("Service notes, maximum 600 characters")
            }
            .padding(7)
            .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.08)))
            HStack {
                Text("Audio and notes stay on this device.")
                Spacer()
                Text("\(audio.notes.count) / 600")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.42))
        }
        .flowCard()
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "iphone.gen3")
            Text("Worship Harvest OnCue works offline. Imported audio is copied into the app on this device.")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.white.opacity(0.42))
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }

    private func sectionTitle(_ title: String, subtitle: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 31, height: 31)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.48))
            }
            Spacer(minLength: 0)
        }
    }

    private func editSlot(_ group: AudioGroup, _ index: Int, _ keyName: String? = nil) {
        editingSlot = EditingSlot(group: group, index: index, keyName: keyName)
    }
}

private struct AddServiceSectionSheet: View {
    let onAdd: (String, ServiceSectionKind, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: ServiceSectionKind = .songs
    @State private var songCount = 4

    var body: some View {
        NavigationStack {
            Form {
                Section("New section") {
                    TextField("Section name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Section type", selection: $kind) {
                        ForEach(ServiceSectionKind.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if kind == .songs || kind == .responseMinistry {
                        Stepper("Song slots: \(songCount)", value: $songCount, in: 1...4)
                    } else if kind == .specialMusic {
                        Text("Special music starts with one song slot.").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("This section includes one repeating loop slot.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd(name, kind, songCount); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

private struct EditServiceSectionSheet: View {
    let section: ServiceSection
    let onSave: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var songCount: Int

    init(section: ServiceSection, onSave: @escaping (String, Int) -> Void) {
        self.section = section
        self.onSave = onSave
        _title = State(initialValue: section.title)
        _songCount = State(initialValue: min(4, max(1, section.songSlotIDs.count)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Section name") { TextField("Name", text: $title).textInputAutocapitalization(.words) }
                if section.kind == .songs || section.kind == .responseMinistry {
                    Section("Song slots") {
                        Stepper("Songs: \(songCount)", value: $songCount, in: 1...4)
                        if section.kind == .responseMinistry {
                            Text("The loop slot stays in this section.").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(title, songCount); dismiss() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }
}

private struct FlowSegmentCard: View {
    let segment: ServiceSection
    @ObservedObject var audio: AudioLibrary
    let onEdit: (AudioGroup, Int, String?) -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @State private var poppedSlotID: UUID?

    private var tint: Color { segment.kind == .loop ? Color(red: 0.58, green: 0.82, blue: 0.77) : .amber }
    private var songIndices: [Int] {
        segment.songSlotIDs.compactMap { id in audio.songs.firstIndex(where: { $0.id == id }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: segment.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 31, height: 31)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(segment.subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.48))
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Edit section", systemImage: "pencil", action: onRename)
                    Button("Delete section and audio", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Edit \(segment.title) section")
            }

            if let loopID = segment.loopSlotID, let loopIndex = audio.loops.firstIndex(where: { $0.id == loopID }) {
                slotButton(group: .loops, index: loopIndex, wide: true, songPosition: nil)
            }

            if !songIndices.isEmpty {
                if segment.kind == .responseMinistry {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note.list").font(.system(size: 10, weight: .bold))
                        Text("RESPONSE SONGS · DRAG TO REORDER")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.7)
                    }
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 1)
                }
                let columnCount = songIndices.count == 1 ? 1 : 2
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(songIndices.enumerated()), id: \.offset) { position, index in
                        slotButton(group: .songs, index: index, wide: songIndices.count == 1, songPosition: position)
                    }
                }
            }
        }
        .flowCard()
    }

    @ViewBuilder
    private func slotButton(group: AudioGroup, index: Int, wide: Bool, songPosition: Int?) -> some View {
        let slot = audio.slot(for: group, at: index)
        let slotTint = group == .loops ? Color(red: 0.58, green: 0.82, blue: 0.77) : Color.amber
        let isPlaying = group == .loops ? audio.playingLoopIndex == index : audio.playingSongIndices.contains(index)
        let tile = ZStack(alignment: .topTrailing) {
            Button {
                if !slot.isLoaded {
                    onEdit(group, index, nil)
                } else {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { poppedSlotID = slot.id }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 160_000_000)
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                            if poppedSlotID == slot.id { poppedSlotID = nil }
                        }
                    }
                    if group == .loops { audio.playLoop(at: index) }
                    else { audio.playSong(at: index) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: group == .loops ? (isPlaying ? "pause.fill" : "repeat") : (isPlaying ? "pause.fill" : "play.fill"))
                        .font(.system(size: wide ? 16 : 12, weight: .bold))
                        .foregroundStyle(isPlaying ? .black : slotTint)
                        .frame(width: wide ? 38 : 30, height: wide ? 38 : 30)
                        .background(isPlaying ? slotTint : slotTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.label)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(.white)
                        Text(slot.isLoaded ? (isPlaying ? "PLAYING" : (slot.originalFileName ?? "READY")) : "TAP TO ADD AUDIO")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .foregroundStyle(isPlaying ? slotTint : .white.opacity(0.42))
                    }
                    Spacer(minLength: 4)
                    if !wide, songPosition != nil {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: wide ? 66 : 72, alignment: .leading)
                .background {
                    if slot.isLoaded {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(LinearGradient(colors: [slotTint.opacity(isPlaying ? 0.30 : 0.19), slotTint.opacity(isPlaying ? 0.12 : 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: slotTint.opacity(isPlaying ? 0.22 : 0.10), radius: 3, x: 0, y: 4)
                            .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.18), lineWidth: 1) }
                    } else {
                        RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.025))
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(isPlaying ? slotTint.opacity(0.65) : (slot.isLoaded ? slotTint.opacity(0.25) : Color.white.opacity(0.20)), style: StrokeStyle(lineWidth: slot.isLoaded ? 1.2 : 1, dash: slot.isLoaded ? [] : [4, 3])))
                .contentShape(RoundedRectangle(cornerRadius: 13))
                .scaleEffect(poppedSlotID == slot.id ? 1.045 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(slot.label), \(slot.isLoaded ? (isPlaying ? "playing" : "ready") : "add audio")")

            Button { onEdit(group, index, nil) } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 25, height: 25)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(slot.label)")
            .padding(.top, 2)
            .padding(.trailing, 2)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.45), value: poppedSlotID)

        if let songPosition {
            tile
                .draggable(String(songPosition))
                .dropDestination(for: String.self) { items, _ in
                    guard let value = items.first, let source = Int(value) else { return false }
                    audio.moveSongSlot(from: source, to: songPosition, within: segment.id)
                    return true
                }
        } else {
            tile
        }
    }
}

private extension View {
    func flowCard() -> some View {
        padding(14)
            .background(Color(red: 0.065, green: 0.09, blue: 0.145), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.075), lineWidth: 1))
    }

    func listRowStyle() -> some View {
        listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private extension Color {
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.34)
}

private extension TimeInterval {
    var playerTime: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let seconds = Int(self)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
