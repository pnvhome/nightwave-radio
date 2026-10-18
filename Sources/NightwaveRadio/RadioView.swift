import SwiftUI
import RadioCore

private let ink = Color(red: 0.039, green: 0.047, blue: 0.078)
private let accent = Color(red: 0.58, green: 0.53, blue: 1)
private let mint = Color(red: 0.44, green: 0.90, blue: 0.79)
private let panel = Color.white.opacity(0.045)

struct RadioView: View {
    @ObservedObject var radio: RadioController
    @State private var showHistory = false
    @State private var showStats = false
    @State private var showAbout = false
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 216)
            Rectangle().fill(.white.opacity(0.07)).frame(width: 1)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if !radio.modelAvailable { downloadCard }
                        if showStats { statistics }
                        else if showHistory { history }
                        else { stationGrid; soundOptions; promptEditor }
                        if let error = radio.error { errorCard(error) }
                    }.padding(30)
                }
                player
            }
        }
        .background(ink)
        .foregroundStyle(.white.opacity(0.9))
        .font(.system(size: 13))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in radio.refreshModel() }
        .sheet(isPresented: $showAbout) { about }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [accent, Color(red: 0.25, green: 0.23, blue: 0.54)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "waveform").font(.system(size: 22, weight: .semibold))
                }.frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("NIGHTWAVE").font(.system(size: 12, weight: .heavy, design: .rounded)).tracking(1.5)
                    Text("RADIO").font(.system(size: 10, weight: .medium)).tracking(4).foregroundStyle(.white.opacity(0.4))
                }
            }.padding(.top, 48).padding(.bottom, 36)
            Text("YOUR SPACE").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.32)).padding(.bottom, 12)
            nav("Stations", icon: "dot.radiowaves.left.and.right", selected: !showHistory && !showStats) { showHistory = false; showStats = false }
            nav("Recordings", icon: "square.stack.fill", selected: showHistory && !showStats) { showHistory = true; showStats = false }
            nav("Statistics", icon: "chart.bar.xaxis", selected: showStats) { showStats = true }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(radio.modelAvailable ? mint : .orange).frame(width: 6, height: 6)
                    Text(radio.modelAvailable ? "YuE2 · ready" : "YuE2 model needed").font(.system(size: 11, weight: .medium))
                }
                Text("Nightwave Radio \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                    .font(.system(size: 10, weight: .medium).monospacedDigit()).foregroundStyle(accent.opacity(0.8))
                Text("Local on your Mac\nInstrumental LoRA included")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.38)).lineSpacing(4)
                Button { radio.openModelFolder() } label: {
                    Label("Open model folder", systemImage: "folder")
                }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(accent)
                    .help("Open in Finder. To free disk space, stop radio playback and downloads before removing the model in Finder.")
                Button("Choose model folder") { radio.chooseModel() }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(accent).disabled(radio.busy)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 14))
            HStack {
                Button { showAbout = true } label: { Label("About", systemImage: "info.circle") }
                Spacer()
                Button { radio.openLog() } label: { Image(systemName: "doc.text") }.help("Engine log")
            }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.white.opacity(0.35)).padding(.top, 20).padding(.bottom, 20)
        }.padding(.horizontal, 18).background(Color.white.opacity(0.012))
    }
    private func nav(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) { Image(systemName: icon).frame(width: 18); Text(title).fontWeight(.medium); Spacer() }
                .padding(.horizontal, 13).padding(.vertical, 13)
                .foregroundStyle(selected ? .white : .white.opacity(0.45))
                .background(selected ? accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 11))
        }.buttonStyle(.plain).padding(.bottom, 5)
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 9) {
                Text("A SOUNDTRACK THAT KEEPS EVOLVING").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(accent)
                Text(showStats ? "Your radio in numbers" : showHistory ? "Your night sessions" : "Find your frequency")
                    .font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.6)
                Text(showStats ? "Usage, speed and resources — all on your Mac." : showHistory ? "Every generated track stays on your Mac." : "Choose a mood. Let YuE2 compose the rest.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.42))
            }
            Spacer()
            Label("INSTRUMENTAL", systemImage: "pianokeys")
                .font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(mint)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(mint.opacity(0.08), in: Capsule()).overlay(Capsule().stroke(mint.opacity(0.16)))
        }.padding(.top, 18)
    }
    private var stationGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("01", "Choose a station", detail: "6 moods")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Station.allCases) { station in
                    let selected = radio.settings.station == station
                    let color = stationColor(station)
                    Button { radio.settings.selectStation(station) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: station.symbol).font(.system(size: 22, weight: .light)).foregroundStyle(color)
                                Spacer()
                                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent).font(.system(size: 15)) }
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(station.title).font(.system(size: 13, weight: .semibold))
                                Text(station.subtitle).font(.system(size: 9)).foregroundStyle(.white.opacity(0.42)).lineLimit(2).frame(height: 24, alignment: .top)
                            }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(LinearGradient(colors: [color.opacity(selected ? 0.15 : 0.075), panel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? accent.opacity(0.8) : .white.opacity(0.06), lineWidth: selected ? 1.3 : 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private var soundOptions: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("02", "Shape your sound", detail: "Changes apply to the next track")
            HStack(spacing: 8) {
                option("Vinyl", icon: "opticaldisc", value: $radio.settings.vinyl)
                option("Soft beats", icon: "waveform.path", value: $radio.settings.softDrums, disabled: radio.settings.beatless)
                option("Beatless", icon: "wind", value: $radio.settings.beatless)
                option("Space", icon: "sparkles", value: $radio.settings.space)
                option("Darker", icon: "moon.fill", value: $radio.settings.darkMood)
            }
        }
    }
    private func option(_ title: String, icon: String, value: Binding<Bool>, disabled: Bool = false) -> some View {
        Button { value.wrappedValue.toggle() } label: {
            HStack(spacing: 6) { Image(systemName: icon); Text(title) }
                .font(.system(size: 10, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 10)
                .foregroundStyle(value.wrappedValue && !disabled ? accent : .white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .background(value.wrappedValue && !disabled ? accent.opacity(0.13) : panel, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(value.wrappedValue && !disabled ? accent.opacity(0.25) : .white.opacity(0.04)))
        }.buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.35 : 1)
    }
    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("03", "Or describe your sound", detail: "Optional")
            ZStack(alignment: .topLeading) {
                if radio.settings.customPrompt.isEmpty {
                    Text("For example: warm piano, rain outside, unhurried bass.\nDescribe instruments, mood and atmosphere in your own words.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.24)).lineSpacing(5).padding(14).allowsHitTesting(false)
                }
                TextEditor(text: $radio.settings.customPrompt).font(.system(size: 12)).lineSpacing(5)
                    .scrollContentBackground(.hidden).padding(9).frame(height: 88)
            }.background(panel, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.07)))
            HStack {
                Text("Your description adds to the selected style. English usually works best with YuE2.")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.32))
                Spacer()
                Text("\(radio.settings.customPrompt.count)/3000").font(.system(size: 9).monospacedDigit()).foregroundStyle(radio.settings.customPrompt.count > 3000 ? .orange : .white.opacity(0.25))
            }
            HStack {
                Text("Track length").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                Picker("Track length", selection: $radio.settings.duration) {
                    Text("1 min").tag(60); Text("2 min").tag(120); Text("3 min").tag(180); Text("4 min").tag(240)
                }.labelsHidden().pickerStyle(.segmented).frame(width: 245)
                Spacer()
                Text("32 steps · quality").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
            }.padding(.top, 2)
        }
    }
    private var player: some View {
        VStack(spacing: 15) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [accent.opacity(0.3), mint.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: radio.current == nil ? "dot.radiowaves.left.and.right" : "waveform").font(.system(size: 22)).foregroundStyle(accent)
                }.frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 6) {
                    Text(radio.current?.title ?? "Your broadcast starts here").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        if radio.running || radio.downloading { Circle().fill(mint).frame(width: 5, height: 5) }
                        Text(radio.status).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                    }
                    if let value = radio.generationProgress { ProgressView(value: value).tint(accent).frame(maxWidth: 240) }
                }
                Spacer(minLength: 8)
                if radio.current != nil {
                    Button { radio.togglePause() } label: { Image(systemName: radio.paused ? "play.fill" : "pause.fill").font(.system(size: 17)).frame(width: 40, height: 40) }.buttonStyle(.plain)
                    Button { radio.skip() } label: { Image(systemName: "forward.end.fill").font(.system(size: 15)) }.buttonStyle(.plain).help("Next track")
                }
                if radio.busy || radio.current != nil {
                    Button { radio.stop() } label: { Label("Stop", systemImage: "stop.fill").font(.system(size: 11)).padding(.horizontal, 16).padding(.vertical, 12).background(panel, in: Capsule()) }.buttonStyle(.plain).help("Stop the radio and release model memory")
                } else {
                    Button { radio.start() } label: {
                        Label("Start radio", systemImage: "play.fill").font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 21).padding(.vertical, 13).background(accent, in: Capsule()).foregroundStyle(.white)
                    }.buttonStyle(.plain).disabled(!radio.modelAvailable)
                }
            }
            if radio.current != nil {
                HStack(spacing: 10) {
                    Text(time(radio.elapsed)).monospacedDigit()
                    Slider(value: Binding(get: { radio.elapsed }, set: { radio.seek($0) }), in: 0...max(1, radio.total)).tint(accent)
                    Text(time(radio.total)).monospacedDigit()
                    Image(systemName: "speaker.wave.2.fill").padding(.leading, 12)
                    Slider(value: $radio.settings.volume, in: 0...1).tint(.white.opacity(0.5)).frame(width: 80)
                }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.35))
            }
            HStack {
                Text(radio.queued == nil ? "Tracks are saved automatically" : "Up next: \(radio.queued!.title)")
                Spacer()
                Button("Open recordings folder ↗") { radio.openTracks() }.buttonStyle(.plain)
            }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
        }.padding(.horizontal, 30).padding(.vertical, 22).background(Color(red: 0.062, green: 0.07, blue: 0.11))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }
    private var downloadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Music model required", systemImage: "arrow.down.circle").font(.system(size: 16, weight: .semibold))
            Text("YuE2 3B · 8-bit · about 4.5 GB. Choose its folder if already installed. The instrumental LoRA is included in the app.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
            HStack {
                Button(radio.downloading ? "Downloading…" : "Download model") { radio.download() }.disabled(radio.busy)
                Button("Choose folder") { radio.chooseModel() }.disabled(radio.busy)
                if radio.downloading { ProgressView().controlSize(.small); Button("Cancel") { radio.stop() } }
            }
            if radio.downloading {
                HStack {
                    ProgressView(value: radio.downloadProgress.fraction).tint(accent)
                    Text("\(Int(radio.downloadProgress.fraction * 100))%")
                        .font(.system(size: 12).monospacedDigit()).frame(width: 40, alignment: .trailing)
                }
                Text(radio.downloadProgress.detail).font(.system(size: 12).monospacedDigit()).foregroundStyle(.secondary)
                Text("Folder: " + ModelLibrary.defaultURL.path).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
    private var statistics: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 13) {
                sectionTitle("01", "Lifetime usage", detail: "Saved between sessions")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard("Tracks created", value: String(radio.usage.tracks), detail: "This session: \(radio.sessionUsage.tracks)", icon: "waveform")
                    statCard("Music composed", value: duration(radio.usage.musicSeconds), detail: "This session: " + duration(radio.sessionUsage.musicSeconds), icon: "music.note")
                    statCard("Listening time", value: duration(radio.usage.listeningSeconds), detail: "This session: " + duration(radio.sessionUsage.listeningSeconds), icon: "headphones")
                    statCard("Generation speed", value: radio.usage.generationSpeed.map { String(format: "%.1f×", $0) } ?? "—",
                             detail: radio.lastGenerationSeconds.map { "Last track: " + duration($0) } ?? "Available after generation", icon: "bolt.fill")
                }
                Text("2× means two minutes of music per minute of generation. Model loading is excluded. Missing generation times for older recordings cannot be recovered.")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.35)).lineSpacing(4)
            }
            VStack(alignment: .leading, spacing: 13) {
                sectionTitle("02", "Live resources", detail: "Updated every 2 seconds")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard("Engine memory", value: radio.resources.engineRunning ? bytes(radio.resources.engineBytes) : "Stopped", detail: "YuE2 · process RSS", icon: "memorychip")
                    statCard("Radio CPU", value: radio.resources.cpuPercent.map { String(format: "%.0f %%", $0) } ?? "—", detail: "100% = one CPU core", icon: "cpu")
                    statCard("Whole Mac GPU", value: radio.resources.gpuPercent.map { String(format: "%.0f %%", $0) } ?? "—", detail: "Includes other applications", icon: "square.3.layers.3d")
                    statCard("App memory", value: bytes(radio.resources.applicationBytes), detail: "Interface · process RSS", icon: "macwindow")
                    statCard("Recordings on disk", value: bytes(radio.resources.tracksBytes, disk: true), detail: "Audio, scores and reports", icon: "waveform.path")
                    statCard("Free disk space", value: bytes(radio.resources.diskFreeBytes, disk: true), detail: "Volume containing recordings", icon: "internaldrive")
                }
                Text("RSS is resident process memory, not a complete measure of shared GPU memory. GPU usage covers the whole Mac. A dash means unavailable. Recording sizes update every 30 seconds.")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.35)).lineSpacing(4)
                HStack(spacing: 8) {
                    Circle().fill(mint).frame(width: 6, height: 6)
                    Text("Statistics stay on this Mac. No telemetry is sent.")
                }.font(.system(size: 10)).foregroundStyle(mint.opacity(0.7)).padding(.top, 4)
            }
        }
    }
    private func statCard(_ title: String, value: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)); Spacer(); Image(systemName: icon).foregroundStyle(accent.opacity(0.7)) }
            Text(value).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            Text(detail).font(.system(size: 9)).foregroundStyle(.white.opacity(0.3)).lineLimit(2)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06)))
    }
    private func bytes(_ amount: UInt64?, disk: Bool = false) -> String {
        guard let amount else { return "—" }
        if amount == 0 { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: Int64(clamping: amount), countStyle: disk ? .file : .memory)
    }
    private func duration(_ seconds: Double) -> String {
        let value = Int(max(0, seconds))
        if value >= 3600 { return "\(value / 3600) h \((value % 3600) / 60) min" }
        if value >= 60 { return "\(value / 60) min \(value % 60) s" }
        return "\(value) s"
    }
    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            if radio.history.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "waveform.path").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(accent)
                    Text("Your music will appear here").font(.system(size: 18, weight: .medium))
                    Text("Start a station. Every generated track is saved automatically.").foregroundStyle(.secondary)
                    Button("Choose a station") { showHistory = false }
                }.frame(maxWidth: .infinity).padding(.vertical, 100)
            }
            ForEach(radio.history) { track in
                HStack(spacing: 14) {
                    Image(systemName: "waveform").foregroundStyle(accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(track.title).fontWeight(.medium)
                        Text(track.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Show in Finder ↗") { radio.reveal(track) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(accent)
                }.padding(15).background(panel, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) { Text(message).font(.system(size: 12)); Button("Open log") { radio.openLog() }.font(.system(size: 10)) }
            Spacer(); Button { radio.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
        }.padding(16).background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
    private var about: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nightwave Radio").font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("Music is generated locally with MLX-Serve and YuE2. No chat model is required. Internet access is needed for the initial model download.")
            Text("Instrumental mode uses Mothersuperior AR LoRA and official YuE2 score transformation. Results can vary; this mode does not detect vocals in the rendered audio.").foregroundStyle(.secondary)
            Text("YuE2 and the LoRA are licensed under CC BY-NC 4.0 for non-commercial use. Full component licenses are included in the app.").font(.system(size: 11)).foregroundStyle(.secondary)
            HStack { Button("Licenses") { if let url = Bundle.main.resourceURL?.appendingPathComponent("Licenses") { NSWorkspace.shared.open(url) } }; Spacer(); Button("Done") { showAbout = false }.keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 500)
    }
    private func sectionTitle(_ number: String, _ title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(number).font(.system(size: 9, weight: .medium).monospaced()).foregroundStyle(accent.opacity(0.7))
            Text(title).font(.system(size: 12, weight: .medium))
            Spacer(); Text(detail).font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
        }
    }
    private func stationColor(_ station: Station) -> Color {
        switch station { case .lofi: return Color(red: 0.86, green: 0.62, blue: 0.48); case .quiet: return Color(red: 0.62, green: 0.68, blue: 0.94); case .cyberpunk: return Color(red: 0.87, green: 0.38, blue: 0.72); case .synthwave: return Color(red: 0.99, green: 0.61, blue: 0.42); case .ambient: return mint; case .custom: return accent }
    }
    private func time(_ value: TimeInterval) -> String { String(format: "%d:%02d", Int(value) / 60, Int(value) % 60) }
}
