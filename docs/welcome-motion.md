# Welcome icon motion

The welcome illustration uses a static SwiftUI glow and a separate native icon
layer. `helper/WelcomeArt.swift` caches the icon at the display's backing scale
and supplies one four-second Core Animation translation loop. No SwiftUI state,
layout or timer is updated for each animation frame. Only the icon moves.

The layer pauses when hidden/occluded, resumes from its paused time, becomes
static under Reduce Motion, and removes its animation and window observers on
detachment/disposal. The native view has padding around the icon's travel.

## Verification

Still onboarding renders use a fixed-phase SwiftUI fallback because ImageRenderer
cannot render NSViewRepresentable. They are useful for layout, not evidence of
live animation smoothness. When changing this animation, use the production view
in the live harness on an interactive macOS desktop:

```sh
xcrun swiftc -O -swift-version 5 -parse-as-library \
  helper/WelcomeArt.swift scripts/verify-welcome-motion.swift \
  -o target/verify-welcome-motion
target/verify-welcome-motion assets/app-icon.png target/welcome-motion.json
```

The fixture opens its own visible window for about ten seconds. It records
CADisplayLink callback times and the Core Animation presentation-layer position,
checks that the texture and container stay unchanged, then exercises hiding,
resuming, Reduce Motion and detachment. It does not record the desktop or
microphone, alter system accessibility settings, or inspect personal captures.
Do not run it as a headless test or call a hidden-window result a live pass.

The report measures callback cadence and presentation-layer state, not GPU
scanout. It reports late callbacks rather than implying zero dropped frames.
The timing gate requires a stable 95th percentile and no large callback stalls
in the sampled interval; it is not a universal frame-rate guarantee.

## Verification on 2026-10-20

Version `0.3.8-local.3`, on the user's 144 Hz display:

- Final live run: 1,151 samples after warm-up; median 6.95 ms, p95 7.07 ms,
  maximum 14.24 ms. One interval exceeded 1.5 times the median.
- Icon traversed both three-point extremes; one texture and one container
  position throughout the run. All lifecycle checks passed.
- The first fixture attempt failed because its window was occluded. The app
  correctly kept motion paused. The fixture was corrected to present a visible
  window; the visibility assertion was retained.
- 257 application tests passed, with one existing performance benchmark ignored.
  Exclusion checks and all four exclusion-policy tests passed.
- Packaged CLI, synthetic export/frame decoding and strict signature checks passed.
- The installed app was updated and relaunched. A read-only sample of its helper
  contained no WelcomeArt or TimelineView update-filter stack entries. It was
  not a controlled CPU comparison and is not reported as a CPU speedup.

The separate how-it-works demo and other onboarding illustrations are outside
this change. All local-only exclusions remain in force.
