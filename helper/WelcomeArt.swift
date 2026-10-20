import AppKit
import QuartzCore
import SwiftUI

/// Only the icon moves. The blurred glow never participates in the animation.
struct WelcomeArt: View {
  let icon: NSImage?
  var fixedPhase: Double? = nil
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Circle()
        .fill(Color(red: 1, green: 59.0 / 255, blue: 48.0 / 255).opacity(0.22))
        .frame(width: 150, height: 150)
        .blur(radius: 46)
      if let phase = fixedPhase {
        // ImageRenderer cannot render NSViewRepresentable. Static previews use the
        // same position and artwork without creating a clock or a native window.
        Group {
          if let icon {
            Image(nsImage: icon).resizable().interpolation(.high).frame(width: 128, height: 128)
          } else {
            RoundedRectangle(cornerRadius: 28).fill(Color(white: 29.0 / 255)).frame(width: 112, height: 112)
          }
        }
        .offset(y: -WelcomeIconView.displacement(at: phase))
      } else {
        WelcomeIcon(icon: icon, reduceMotion: reduceMotion)
          .frame(width: 150, height: 150)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct WelcomeIcon: NSViewRepresentable {
  let icon: NSImage?
  let reduceMotion: Bool

  func makeNSView(context: Context) -> WelcomeIconView {
    WelcomeIconView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
  }

  func updateNSView(_ view: WelcomeIconView, context: Context) {
    view.configure(icon: icon, reduceMotion: reduceMotion)
  }

  static func dismantleNSView(_ view: WelcomeIconView, coordinator: ()) {
    view.dispose()
  }
}

/// The render server interpolates one cached texture. There is no per-frame
/// SwiftUI state, layout, timer, or redraw in this view.
final class WelcomeIconView: NSView {
  static let animationKey = "welcome-float"
  private let artwork = CALayer()
  private var image: NSImage?
  private var imageConfigured = false
  private var rasterScale: CGFloat = 0
  private var reduceMotion = false
  private var disposed = false
  private weak var observedWindow: NSWindow?
  private static let visibilityNotifications: [Notification.Name] = [
    NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
    NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification,
  ]

  static func displacement(at phase: Double) -> Double {
    3 * sin(phase * 2 * .pi)
  }

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer = CALayer()
    layerContentsRedrawPolicy = .onSetNeedsDisplay
    artwork.name = "ScrawlWelcomeIcon"
    artwork.contentsGravity = .resizeAspect
    layer?.addSublayer(artwork)
  }

  required init?(coder: NSCoder) { nil }

  func configure(icon: NSImage?, reduceMotion: Bool) {
    if !imageConfigured || image !== icon {
      image = icon
      imageConfigured = true
      rasterScale = 0
      updateArtwork()
    }
    self.reduceMotion = reduceMotion
    updatePlayback()
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let edge: CGFloat = image == nil ? 112 : 128
    artwork.bounds = NSRect(x: 0, y: 0, width: edge, height: edge)
    artwork.position = CGPoint(x: bounds.midX, y: bounds.midY)
    CATransaction.commit()
  }

  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    updateArtwork()
  }

  private func updateArtwork() {
    let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    guard rasterScale != scale else { return }
    rasterScale = scale
    let pixels = Int((128 * scale).rounded(.up))
    let source = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    let bitmap = CGContext(
      data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    bitmap?.interpolationQuality = .high
    if let source { bitmap?.draw(source, in: CGRect(x: 0, y: 0, width: pixels, height: pixels)) }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    artwork.contents = source == nil ? nil : (bitmap?.makeImage() ?? source)
    artwork.contentsScale = scale
    artwork.backgroundColor = source == nil ? NSColor(calibratedWhite: 29.0 / 255, alpha: 1).cgColor : nil
    artwork.cornerRadius = source == nil ? 28 : 0
    CATransaction.commit()
    needsLayout = true
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    stopObservingWindow()
    if let window {
      observedWindow = window
      for name in Self.visibilityNotifications {
        NotificationCenter.default.addObserver(self, selector: #selector(visibilityChanged(_:)), name: name, object: window)
      }
      updateArtwork()
    }
    updatePlayback()
  }

  override func viewDidHide() { super.viewDidHide(); updatePlayback() }
  override func viewDidUnhide() { super.viewDidUnhide(); updatePlayback() }

  @objc private func visibilityChanged(_ notification: Notification) {
    if notification.name == NSWindow.willCloseNotification { stop() }
    else { updatePlayback() }
  }

  private func updatePlayback() {
    guard !disposed, !reduceMotion, let window else { stop(); return }
    let visible = window.isVisible && window.occlusionState.contains(.visible) && !isHiddenOrHasHiddenAncestor
    guard visible else {
      if artwork.animation(forKey: Self.animationKey) != nil && artwork.speed != 0 {
        let paused = artwork.convertTime(CACurrentMediaTime(), from: nil)
        artwork.speed = 0
        artwork.timeOffset = paused
      }
      return
    }
    if artwork.animation(forKey: Self.animationKey) == nil {
      let motion = CAKeyframeAnimation(keyPath: "transform.translation.y")
      motion.values = (0...120).map { Self.displacement(at: Double($0) / 120) }
      motion.duration = 4
      motion.repeatCount = .infinity
      motion.calculationMode = .linear
      motion.timingFunction = CAMediaTimingFunction(name: .linear)
      artwork.add(motion, forKey: Self.animationKey)
    } else if artwork.speed == 0 {
      let paused = artwork.timeOffset
      artwork.speed = 1
      artwork.timeOffset = 0
      artwork.beginTime = 0
      artwork.beginTime = artwork.convertTime(CACurrentMediaTime(), from: nil) - paused
    }
  }

  private func stop() {
    artwork.removeAnimation(forKey: Self.animationKey)
    artwork.speed = 1
    artwork.timeOffset = 0
    artwork.beginTime = 0
  }

  func dispose() {
    disposed = true
    stop()
    stopObservingWindow()
  }

  private func stopObservingWindow() {
    if let observedWindow {
      for name in Self.visibilityNotifications {
        NotificationCenter.default.removeObserver(self, name: name, object: observedWindow)
      }
    }
    observedWindow = nil
  }

  deinit { NotificationCenter.default.removeObserver(self) }
}
