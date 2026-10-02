# analyzer — macOS app

The macOS client for [analyzer][core], a native real-time audio and acoustic
measurement tool. Swift and SwiftUI, with two Metal renderers.

> **Status: pre-alpha.** It builds, launches and captures from real hardware.
> `analyzer` is a working name.

[core]: https://github.com/rossb468/analyzer

## Building

The C++ core is a submodule pinned to a known revision, so this repository
builds against one specific core rather than whatever happens to be checked out
beside it.

```bash
git clone --recursive https://github.com/rossb468/analyzer-macos.git
cd analyzer-macos
./build.sh --run
```

If you already cloned without `--recursive`:

```bash
git submodule update --init
```

`build.sh` does three things: builds the core into one static library,
`libanalyzer.a`, with CMake (`brew install cmake`); compiles every Swift source
against it and the core's C header; and lays out the bundle. There is no Xcode project — a `.pbxproj` is a large generated file that
is painful to review and merge, and nothing here needs one.

`--release` for an optimised build, `--run` to launch it afterwards.

## Bumping the core

```bash
git -C core fetch origin
git -C core checkout <revision>
git add core && git commit -m "chore: bump core to <revision>"
```

The pinned revision appears in the diff, so which core a given app build was
made against is recorded rather than implied.

## What lives here, and what does not

Only the interface. View state, layout, gestures and Metal draw calls.

Analysis configuration, unit conversion, smoothing, axis scaling, trace
management, calibration and file I/O all live in the core, reached over its C
ABI. Swift never computes a bin-to-pixel mapping — it asks
`analyzer_freq_to_x`, `analyzer_x_to_freq`, `analyzer_db_to_y`,
`analyzer_y_to_db`, `analyzer_phase_to_y`, `analyzer_coherence_to_y`.

That is not tidiness. It is the difference between the Windows and Linux clients
being weeks of work or months, and the temptation to break it peaks exactly when
moving fast.

## The app

A sidebar of tools, a Metal plot, and a per-section inspector.

| Section | What it does |
|---|---|
| RTA | Live spectrum, with a long-term average |
| Transfer | Dual-FFT magnitude, phase and coherence against a reference |
| Measure | Swept measurement: impulse response, decay times, gated response |
| Spectrogram | Running spectrogram on a GPU ring texture |
| Equaliser | Graphic and parametric EQ, target curves, automatic fitting, filter export |
| Traces | Captured curves overlaid for comparison |

Program settings — startup defaults, axis ranges, calibration — are in a
standard `Settings` scene under Command-comma. They are stored and validated by
the core, not in `UserDefaults`, so the other clients inherit them.

## Licence

Dual MIT OR Apache-2.0, matching the core. See `LICENSE-MIT` and
`LICENSE-APACHE`.
