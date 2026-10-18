import SwiftUI
import AppKit
import RadioCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: RadioController?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { controller?.stop() }
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.activate(ignoringOtherApps: true) }
}

@main
struct NightwaveRadioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var controller: RadioController
    init() {
        if CommandLine.arguments.contains("--first-run-preview") {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("nightwave-first-run-" + UUID().uuidString)
            _controller = StateObject(wrappedValue: RadioController(dataDirectory: root, tracksDirectory: root.appendingPathComponent("Tracks"), modelURL: root.appendingPathComponent("Missing Model")))
        } else { _controller = StateObject(wrappedValue: RadioController()) }
    }
    var body: some Scene {
        WindowGroup("Nightwave Radio") {
            RadioView(radio: controller)
                .preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 740)
                .onAppear {
                    delegate.controller = controller
                    if CommandLine.arguments.contains("--smoke-test") { runSmoke() }
                    if CommandLine.arguments.contains("--queue-test") { runQueueTest() }
                }
        }
        .defaultSize(width: 1120, height: 860)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Radio") {
                Button("Start") { controller.start() }.disabled(controller.busy).keyboardShortcut("r", modifiers: .command)
                Button("Pause / resume") { controller.togglePause() }.keyboardShortcut(" ", modifiers: [])
                Button("Next track") { controller.skip() }.keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Stop and release memory") { controller.stop() }.keyboardShortcut(".", modifiers: .command)
                Divider()
                Button("Show recordings") { controller.openTracks() }
                Button("Open log") { controller.openLog() }
            }
        }
    }
    private func runQueueTest() {
        Task { @MainActor in
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("nightwave-queue-" + UUID().uuidString)
            let radio = RadioController(dataDirectory: root, tracksDirectory: root.appendingPathComponent("Tracks"))
            delegate.controller = radio
            radio.settings.duration = 5; radio.settings.volume = 0
            radio.start()
            do {
                let deadline = Date().addingTimeInterval(180)
                for target in 1...3 {
                    while radio.history.count < target {
                        if let error = radio.error { throw RadioFailure(error) }
                        guard Date() < deadline else { throw RadioFailure("Queue test timed out") }
                        try await Task.sleep(nanoseconds: 200_000_000)
                    }
                    if target == 1 {
                        guard radio.current != nil else { throw RadioFailure("Playback did not start") }
                        radio.togglePause()
                        guard radio.paused else { throw RadioFailure("Pause failed") }
                    } else {
                        guard let next = radio.queued else { throw RadioFailure("Track was not queued") }
                        radio.togglePause()
                        guard !radio.paused else { throw RadioFailure("Resume failed") }
                        if target == 2 {
                            radio.skip()
                            guard radio.current?.id == next.id else { throw RadioFailure("Skip failed") }
                            radio.togglePause()
                        } else {
                            while radio.current?.id != next.id {
                                guard Date() < deadline else { throw RadioFailure("Automatic transition failed") }
                                try await Task.sleep(nanoseconds: 200_000_000)
                            }
                        }
                    }
                }
                guard radio.usage.tracks == 3, radio.sessionUsage.tracks == 3,
                      radio.usage.musicSeconds > 14, radio.usage.generationSeconds > 0,
                      radio.usage.listeningSeconds > 0,
                      radio.resources.engineRunning, (radio.resources.engineBytes ?? 0) > 0,
                      (radio.resources.applicationBytes ?? 0) > 0 else {
                    throw RadioFailure("Usage or resource counters failed")
                }
                let persisted = try JSONDecoder().decode(UsageTotals.self, from: Data(contentsOf: root.appendingPathComponent("usage.json")))
                guard persisted.tracks == 3 else { throw RadioFailure("Usage persistence failed") }
                radio.stop()
                guard !radio.resources.engineRunning && radio.resources.engineBytes == nil else { throw RadioFailure("Stopped engine resources did not reset") }
                guard !radio.running && radio.current == nil else { throw RadioFailure("Stop failed") }
                try "PASS: three sequential tracks, queued playback, pause, resume, skip, automatic transition, stop, usage persistence, live resource counters\n".write(to: root.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
                print("QUEUE PASS: \(root.path)")
                fflush(stdout)
                Darwin.exit(0)
            } catch {
                radio.stop(); print("QUEUE FAIL: \(error.localizedDescription)")
                try? error.localizedDescription.write(to: root.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
                Darwin.exit(1)
            }
        }
    }

    private func runSmoke() {
        Task { @MainActor in
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("nightwave-smoke-" + UUID().uuidString)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let engine = LocalEngine(dataDirectory: root)
            do {
                try await engine.prepare(model: ModelLibrary.defaultURL)
                var settings = RadioSettings(); settings.duration = 5
                let track = try await engine.generate(settings: settings, model: ModelLibrary.defaultURL, index: 0, salt: 1, output: root.appendingPathComponent("test.m4a")) { _, _ in }
                engine.stop()
                try "PASS: bundled engine, installed YuE2, instrumental LoRA, full-score generation\n\(track.path)\n".write(to: root.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
                print("SMOKE PASS: \(root.path)")
                fflush(stdout)
                Darwin.exit(0)
            } catch {
                engine.stop(); print("SMOKE FAIL: \(error.localizedDescription)")
                try? error.localizedDescription.write(to: root.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
                Darwin.exit(1)
            }
        }
    }
}
