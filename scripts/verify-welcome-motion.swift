// Live window check of the production welcome view. No screen/microphone capture.
import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class WelcomeMotionVerification: NSObject, NSApplicationDelegate {
  let output: URL
  let image: NSImage
  var window: NSWindow!
  var displayLink: CADisplayLink?
  var icon: WelcomeIconView?
  var artwork: CALayer?
  var started = 0.0
  var samples: [(Double, Double)] = []
  var textures = Set<UInt>()
  var failures: [String] = []
  var checks: [String: Bool] = [:]
  var rootPositions = Set<String>()

  init(output: URL, image: NSImage) { self.output = output; self.image = image }

  func applicationDidFinishLaunching(_ notification: Notification) {
    window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
                      styleMask: [.titled], backing: .buffered, defer: false)
    window.title = "Scrawl welcome animation verification"
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView:
      WelcomeArt(icon: image).frame(width: 360, height: 260)
        .background(Color(white: 22.0 / 255)).preferredColorScheme(.dark))
    window.level = .floating
    window.collectionBehavior = [.moveToActiveSpace]
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.begin() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
      self.failures.append("live window did not complete within 20 seconds")
      self.finish()
    }
  }

  func findIcon(_ view: NSView) -> WelcomeIconView? {
    if let icon = view as? WelcomeIconView { return icon }
    return view.subviews.lazy.compactMap { self.findIcon($0) }.first
  }

  func require(_ condition: Bool, _ name: String) {
    checks[name] = condition
    if !condition { failures.append(name) }
  }

  func begin() {
    guard let content = window.contentView, let icon = findIcon(content),
          let artwork = icon.layer?.sublayers?.first else {
      failures.append("production icon view not mounted")
      finish(); return
    }
    self.icon = icon
    self.artwork = artwork
    // Exercise both motion modes on this fixture, without changing system settings.
    icon.configure(icon: image, reduceMotion: false)
    require(window.occlusionState.contains(.visible), "test_window_visible")
    require(artwork.animationKeys() == [WelcomeIconView.animationKey], "only_icon_transform_is_animated")
    started = CACurrentMediaTime()
    displayLink = window.displayLink(target: self, selector: #selector(frame(_:)))
    displayLink?.add(to: .main, forMode: .common)
  }

  @objc func frame(_ link: CADisplayLink) {
    let now = CACurrentMediaTime()
    guard let artwork, let icon else { return }
    if now - started > 1, let presented = artwork.presentation() {
      samples.append((now, Double(presented.transform.m42)))
      if let contents = artwork.contents {
        textures.insert(UInt(bitPattern: Unmanaged.passUnretained(contents as AnyObject).toOpaque()))
      }
      if let root = icon.layer?.presentation() {
        rootPositions.insert("\(root.position.x),\(root.position.y),\(root.transform.m41),\(root.transform.m42)")
      }
    }
    if now - started >= 9 {
      displayLink?.invalidate()
      displayLink = nil
      lifecycleChecks()
    }
  }

  func lifecycleChecks() {
    guard let icon, let artwork else { return }
    icon.isHidden = true
    let paused = artwork.timeOffset
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      self.require(artwork.speed == 0 && artwork.timeOffset == paused && paused > 0, "hidden_view_pauses")
      icon.isHidden = false
      self.require(artwork.speed == 1 && artwork.animation(forKey: WelcomeIconView.animationKey) != nil, "visible_view_resumes")
      icon.configure(icon: self.image, reduceMotion: true)
      self.require(artwork.animationKeys()?.isEmpty != false && artwork.transform.m42 == 0, "reduced_motion_is_static")
      icon.configure(icon: self.image, reduceMotion: false)
      self.require(artwork.animation(forKey: WelcomeIconView.animationKey) != nil, "motion_can_resume")
      icon.removeFromSuperview()
      self.require(artwork.animationKeys()?.isEmpty != false, "detached_view_stops")
      icon.dispose()
      self.finish()
    }
  }

  func finish() {
    displayLink?.invalidate()
    let gaps = zip(samples.dropFirst(), samples).map { ($0.0 - $1.0) * 1000 }.sorted()
    let ys = samples.map { $0.1 }
    let median = gaps.isEmpty ? 0 : gaps[gaps.count / 2]
    let p95 = gaps.isEmpty ? 0 : gaps[min(gaps.count - 1, Int(Double(gaps.count) * 0.95))]
    let maximum = gaps.last ?? 0
    require(samples.count >= 200, "enough_live_samples")
    require((ys.min() ?? 0) < -2.9 && (ys.max() ?? 0) > 2.9, "icon_moves_through_both_extremes")
    require(ys.allSatisfy { abs($0) <= 3.01 }, "motion_stays_within_three_points")
    require(textures.count == 1, "cached_texture_is_not_replaced_per_frame")
    require(rootPositions.count == 1, "icon_container_stays_stationary")
    require(median > 0 && p95 <= median * 1.5 && maximum < max(50, median * 3), "display_link_has_no_large_stalls")
    let report: [String: Any] = [
      "status": failures.isEmpty ? "PASS" : "FAIL", "checks": checks, "failures": failures,
      "windowVisible": window?.isVisible ?? false, "windowOnActiveSpace": window?.isOnActiveSpace ?? false,
      "appActive": NSApp.isActive, "windowOcclusionRaw": window?.occlusionState.rawValue ?? 0,
      "samples": samples.count, "medianIntervalMs": median, "p95IntervalMs": p95,
      "maxIntervalMs": maximum, "intervalsOver1_5xMedian": gaps.filter { $0 > median * 1.5 }.count,
      "minIconOffset": ys.min() ?? 0, "maxIconOffset": ys.max() ?? 0,
      "distinctTextures": textures.count, "distinctContainerPositions": rootPositions.count,
      "measurement": "Live production view, CADisplayLink callback intervals and Core Animation presentation layer. Not a GPU scanout or whole-desktop recording."
    ]
    var reportWritten = true
    do {
      let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: output)
      FileHandle.standardOutput.write(data + Data("\n".utf8))
    } catch { reportWritten = false; fputs("Could not write motion report: \(error)\n", stderr) }
    window?.orderOut(nil)
    exit(failures.isEmpty && reportWritten ? 0 : 1)
  }
}

@main
struct VerifyWelcomeMotion {
  @MainActor static func main() {
    umask(0o077)
    guard CommandLine.arguments.count == 3,
          let image = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
      fputs("usage: verify-welcome-motion ICON.png REPORT.json\n", stderr); exit(2)
    }
    let app = NSApplication.shared
    let delegate = WelcomeMotionVerification(output: URL(fileURLWithPath: CommandLine.arguments[2]), image: image)
    app.setActivationPolicy(.regular)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
