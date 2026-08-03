import SwiftUI
import UniformTypeIdentifiers
import AnalyzerFFI

/// The signal generator.
///
/// Two jobs that share one set of controls. It plays a stimulus through the
/// output — which is what the transfer function and the equaliser need — and it
/// writes the same signal to a file, which is what a parity run, a second
/// machine or another analyser needs.
///
/// Both come from the same core rendering, so the file is the signal that was
/// played rather than an approximation of it.
struct GeneratorInspector: View {
    @ObservedObject var model: AnalyzerModel

    var body: some View {
        if !model.canPlay {
            Section {
                OutputHint(model: model, needs: "Playing a signal")
            }
        }

        Section("Signal") {
            Picker("Type", selection: $model.generatorSignal) {
                Text("Sine").tag(AnalyzerSignal_Sine)
                Text("Pink noise").tag(AnalyzerSignal_PinkNoise)
                Text("White noise").tag(AnalyzerSignal_WhiteNoise)
                Text("Sweep").tag(AnalyzerSignal_Sweep)
            }

            if model.generatorSignal == AnalyzerSignal_Sine {
                slider("Frequency", $model.generatorHz, 20...20_000, formatFrequency)
            }

            if model.generatorSignal == AnalyzerSignal_Sweep {
                slider("From", $model.generatorHz, 10...1000, formatFrequency)
                slider("To", $model.generatorEndHz, 1000...24_000, formatFrequency)
            }

            slider("Level", $model.generatorLevelDb, -60...0) {
                String(format: "%.0f dBFS", $0)
            }
        }

        Section("Play") {
            if model.generatorSignal == AnalyzerSignal_Sweep {
                // A sweep is a measurement stimulus, not a steady tone: it has
                // to be started and recorded together for the deconvolution to
                // mean anything. Sending people to the tool that does that is
                // better than playing one here that nothing is listening to.
                Text("A sweep is played as part of a measurement, so that the "
                     + "response is recorded against it. Use the Measure section.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Toggle("Playing", isOn: playing)
                    .disabled(!model.isRunning || !model.canPlay)
                    .help("Plays out of the selected device, and is analysed alongside the input.")
            }
        }

        Section("Write to file") {
            Picker("Depth", selection: $model.generatorDepth) {
                Text("32-bit float").tag(AnalyzerSampleDepth_Float32)
                Text("24-bit").tag(AnalyzerSampleDepth_Int24)
                Text("16-bit").tag(AnalyzerSampleDepth_Int16)
            }
            .help("""
                Float by default: a generated signal has no reason to be \
                quantised, and 16-bit adds dither noise at -96 dBFS to a \
                measurement whose point is measuring a noise floor.
                """)

            slider("Length", $model.generatorSeconds, 0.5...30) {
                String(format: "%.1f s", $0)
            }

            Button {
                model.writeSignal()
            } label: {
                Label("Save signal…", systemImage: "square.and.arrow.down")
            }
            .disabled(model.generatorSignal == AnalyzerSignal_Silence)

            if let written = model.generatorWrote {
                LabeledContent("Wrote") {
                    Text(written)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    /// Playing is the session's stimulus, so this drives the same setting the
    /// toolbar does rather than keeping a second copy of it.
    private var playing: Binding<Bool> {
        Binding(
            get: { model.signal != AnalyzerSignal_Silence },
            set: { model.signal = $0 ? model.generatorSignal : AnalyzerSignal_Silence }
        )
    }

    private func slider(
        _ label: String,
        _ value: Binding<Float>,
        _ range: ClosedRange<Float>,
        _ format: @escaping (Float) -> String
    ) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                Slider(value: value, in: range)
                Text(format(value.wrappedValue))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}
