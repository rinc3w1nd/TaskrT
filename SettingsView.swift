import SwiftUI

struct SettingsView: View {
    @State private var scheme = DueColorScheme.load()

    var body: some View {
        Form {
            Text("Due-Date Color Thresholds")
                .font(.headline)
                .padding(.bottom, 4)

            Stepper("Blue ≥ \(scheme.blueMinDays) days (no due date = Blue)", value: $scheme.blueMinDays, in: 0...365)
            Stepper("Yellow ≥ \(scheme.yellowMinDays) days", value: $scheme.yellowMinDays, in: 0...365)
            Stepper("Orange ≥ \(scheme.orangeMinDays) days", value: $scheme.orangeMinDays, in: 0...365)
            Stepper("Red ≥ \(scheme.redMinDays) days (Crimson below Red)", value: $scheme.redMinDays, in: 0...365)

            Text("Order must be Blue ≥ Yellow ≥ Orange ≥ Red for a sensible gradient.").font(.footnote).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    scheme = .default
                }
                Button("Save") {
                    DueColorScheme.save(scheme)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}