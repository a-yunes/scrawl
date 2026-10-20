// scrawl-helper: the parts of Scrawl that need Swift-only Apple frameworks.
//
//   scrawl-helper devices                               cabled iPhones/iPads (USB registry) as JSON
//   scrawl-helper mirror --out FILE.mov [--device ID] [--microphone UID --microphone-name NAME]
//                                                       live mirror window + native recording (JSON lines)
//   scrawl-helper transcribe FILE                       SpeechAnalyzer transcript with word timings
//   scrawl-helper transcribe-stream                     the same while recording: PCM on stdin, JSON lines (LiveTranscribe.swift)
//   scrawl-helper speech-model [--install]              the speech model's status; install it (JSON lines)
//   scrawl-helper frames MOVIE --out-dir DIR (--every MS | --at MS,MS…) [--max-edge PX]
//   scrawl-helper audio MOVIE OUT.wav                   16 kHz mono PCM of every audio track, mixed
//   scrawl-helper probe MOVIE                           duration and video size
//   scrawl-helper shrink MOVIE --out FILE.mov [--max-edge PX] [--bitrate BPS]   HEVC copy, same timeline
//   scrawl-helper export PLAN.json                      shareable .mp4: crop/camera, burned-in ink, audio (Export.swift)
//   scrawl-helper permissions                           what Scrawl has been granted, as JSON
//   scrawl-helper sck-probe [--watch SECONDS]           can this process capture with ScreenCaptureKit (ScreenProbe.swift)
//   scrawl-helper permission-panel --permission P [--from X,Y,W,H]   drag-to-allow card (PermissionPanel.swift)
//   scrawl-helper onboarding [--shortcut L] [--render DIR]   the welcome window (Onboarding.swift)
//   scrawl-helper settings [--pane P] [--render DIR]         the Settings window (Settings.swift)
//
// Every timestamp in the output is integer milliseconds. Scrawl drives the long-running
// `mirror` command over stdin (`stop`, `cancel`) and reads its events from stdout.

import AppKit
import Foundation
import Darwin

umask(0o077)

func emit(_ object: Any) {
  guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else { return }
  FileHandle.standardOutput.write(data + Data("\n".utf8))
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("scrawl-helper: \(message)\n".utf8))
  exit(1)
}

struct HelperError: LocalizedError {
  let errorDescription: String?
  init(_ message: String) { errorDescription = message }
}

func option(_ name: String, in arguments: [String]) -> String? {
  guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
  return arguments[index + 1]
}

/// Runs async work from a synchronous entry point, keeping the main queue free for AVFoundation.
func runAsync(_ body: @escaping () async throws -> Void) -> Never {
  Task {
    do {
      try await body()
      exit(0)
    } catch {
      fail(error.localizedDescription)
    }
  }
  dispatchMain()
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "transcribe":
  guard arguments.count >= 2 else { fail("transcribe needs a file") }
  runAsync { emit(try await Transcriber.transcribe(URL(filePath: arguments[1]))) }
case "transcribe-stream":
  runAsync { try await LiveTranscriber.run() }
case "speech-model":
  let install = arguments.contains("--install")
  runAsync { await SpeechModel.run(install: install) }
case "frames":
  guard arguments.count >= 2, let dir = option("--out-dir", in: arguments) else {
    fail("frames needs MOVIE --out-dir DIR (--every MS | --at MS,MS…)")
  }
  let maxEdge = option("--max-edge", in: arguments).flatMap(Int.init) ?? 0
  let every = option("--every", in: arguments).flatMap(Int.init)
  let at = option("--at", in: arguments)?.split(separator: ",").compactMap { Int($0) }
  runAsync {
    emit(try await Media.frames(movie: URL(filePath: arguments[1]), outDir: URL(filePath: dir), everyMs: every, atMs: at, maxEdge: maxEdge))
  }
case "audio":
  guard arguments.count >= 3 else { fail("audio needs MOVIE OUT.wav") }
  runAsync { emit(try await Media.exportAudio(movie: URL(filePath: arguments[1]), wav: URL(filePath: arguments[2]))) }
case "shrink":
  guard arguments.count >= 2, let out = option("--out", in: arguments) else { fail("shrink needs MOVIE --out FILE.mov") }
  let maxEdge = option("--max-edge", in: arguments).flatMap(Int.init) ?? 1600
  let bitRate = option("--bitrate", in: arguments).flatMap(Int.init) ?? 2_500_000
  runAsync {
    emit(try await Media.shrink(movie: URL(filePath: arguments[1]), out: URL(filePath: out), maxEdge: maxEdge, bitRate: bitRate))
  }
case "export":
  guard arguments.count >= 2 else { fail("export needs PLAN.json") }
  runAsync { try await Exporter.run(plan: URL(filePath: arguments[1])) }
case "probe":
  guard arguments.count >= 2 else { fail("probe needs MOVIE") }
  runAsync { emit(try await Media.probe(URL(filePath: arguments[1]))) }
case "permission-panel":
  PermissionPanel.run(arguments: arguments)
case "permissions":
  emit(Permissions.statuses())
case "sck-probe":
  let watch = option("--watch", in: arguments).flatMap(Double.init)
  runAsync { await ScreenProbe.run(watch: watch) }
case "onboarding":
  Onboarding.run(arguments: arguments)
case "settings":
  SettingsWindow.run(arguments: arguments)
default:
  fail("usage: scrawl-helper transcribe|transcribe-stream|speech-model|frames|audio|probe|export|shrink|permission-panel|permissions|sck-probe|onboarding|settings …")
}
