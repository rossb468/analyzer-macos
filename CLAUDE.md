# Working on the macOS client

The Swift and SwiftUI front end for `analyzer`. The C++ core is a submodule at
`core/`, pinned to a revision.

**Read `core/CLAUDE.md` too** — it carries the disciplines and traps for
everything below the C ABI, and most changes here are paired with one there.
`core/docs/HANDOFF.md` is the longer narrative.

## Environment

- **CMake builds the core** (`brew install cmake`); Xcode alone does not ship
  it. `build.sh` builds only the `analyzer_bundle` target, which merges every
  core module into `libanalyzer.a`, and links that with `-lc++`.
- Xcode for the app. Swift 6.3+, targeting macOS 14.

## Commands

```bash
./build.sh              # build the bundle
./build.sh --run        # build and launch
./build.sh --release    # optimised
git submodule update --init    # if core/ is empty
```

There is no test suite here. Everything testable is in the core, which has one;
this layer is view code whose correctness is visual. See "You cannot see it".

## Rules that are not style preferences

**No application logic in Swift.** View state, layout, gestures and Metal draw
calls only. Analysis config, unit conversion, smoothing, axis scaling, trace
management, calibration and file I/O live in the core. Swift must never compute
a bin-to-pixel mapping; it calls `analyzer_freq_to_x`, `analyzer_x_to_freq`,
`analyzer_db_to_y`, `analyzer_y_to_db`, `analyzer_phase_to_y`,
`analyzer_coherence_to_y`. This decides whether the Windows and Linux ports are
weeks or months.

The one exception is **drawable pixels to points**, which is a platform
coordinate-space concern rather than an analysis one. `AnalyzerModel.plotScale`
carries the ratio.

**The core owns its state; this mirrors it.** Equaliser bands, target curves,
captured traces and settings are all read back from the core after every write,
never edited locally and assumed to match. That is what stops a fader
controlling a filter it does not describe.

**The core emits no pixels.** Line traces arrive as one value per pixel column
and go straight into a Metal buffer. The spectrogram arrives as one column of
decibels per analysis frame and goes into a GPU ring texture. Compositing either
on the CPU is what makes REW's waterfall slow.

## Traps this codebase has already hit

- **You cannot see it.** Agent sessions have no screen recording or
  accessibility permission, so they can confirm the app builds, launches and
  does not crash — and nothing more. A `List` selection bug that made every
  sidebar row unclickable compiled and ran cleanly. Ask the human to look before
  claiming an interface works.
- **`List(selection:)` takes `Binding<SelectionValue?>`.** Passing a
  non-optional binding compiles, promotes `SelectionValue` to the optional, and
  then silently matches no `.tag()`. Write the optional binding out explicitly.
- **Tick positions come back in drawable pixels, not points.** Placing a SwiftUI
  label at one directly puts it at double its position on any Retina display.
- **Swift has no backslash line-continuation inside string literals.** That is a
  Rust habit. Use `"""` multi-line strings.
- **One device does both directions.** macOS drives one device per audio
  callback, so playing a stimulus and recording the response needs a single
  device that can do both — an Aggregate Device on most laptops. This is the
  most confusing thing about the app for a new user; the explanations in
  `Sources/OutputHint.swift` should stay explanatory rather than becoming terse.
- **The C header is the contract.** `core/include/analyzer.h` is hand-maintained
  in the core, and a change there that the core's own tests are happy with can
  still break Swift - the first sign is a compile error in a file nobody
  touched. Build the app after any change to the core's C ABI.

## Editing

Large multi-hunk edits have gone best as Python patch scripts **written to a
file first, then run** — a heredoc that aborts on an anchor mismatch leaves the
file untouched and forces a full re-run.

`build.sh` compiles `Sources/*.swift` non-recursively, so new files go in that
directory flat, not in subdirectories.

## Git

Conventional Commits, scope `macos` unless something more specific fits. Short
-lived feature branches, rebase or squash onto `main`, no PRs needed. Every
commit must build.

Bumping the core is its own commit: `chore: bump core to <revision>`. The pinned
revision belongs in the diff so the pairing is recorded rather than implied.
