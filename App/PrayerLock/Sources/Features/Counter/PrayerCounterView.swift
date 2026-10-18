import PLDesign
import SwiftUI

/// A counter for repeated prayer — japa on a mala, dhikr on a tasbih, the rosary's decades.
/// Tap anywhere to count a bead; a soft tick on each, a fuller one when a round completes.
/// Nothing is recorded beyond this screen.
struct PrayerCounterView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State var target: Int
    var targets: [Int] = [108, 54, 27, 11]

    @State private var count = 0
    @State private var rounds = 0
    @State private var pulse = false

    init(title: String, target: Int, targets: [Int]? = nil) {
        self.title = title
        _target = State(initialValue: target)
        self.targets = targets ?? Self.defaultTargets(including: target)
    }

    var body: some View {
        ZStack {
            Color.plCanvas.ignoresSafeArea()
            VStack(spacing: PLSpacing.l) {
                header
                Spacer(minLength: PLSpacing.m)
                ring
                Spacer(minLength: PLSpacing.m)
                controls
            }
            .padding(PLSpacing.page)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: count) { _, new in new != 0 }
        .sensoryFeedback(.success, trigger: rounds) { old, new in new > old }
        .accessibilityAction(named: Text("Count one")) { advance() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text("Counting").plEyebrow()
                Text(title)
                    .font(.plTitleSmall)
                    .foregroundStyle(Color.plInk)
                    .lineLimit(2)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.plQuiet(.plAccent))
                .accessibilityIdentifier("counter.done")
        }
    }

    private var ring: some View {
        let progress = Double(count) / Double(max(target, 1))
        return ZStack {
            BeadRing(total: min(target, 108), filled: Int((progress * Double(min(target, 108))).rounded(.down)))
            VStack(spacing: PLSpacing.xxs) {
                Text("\(count)")
                    .font(.system(size: 76, weight: .light, design: .serif).monospacedDigit())
                    .foregroundStyle(Color.plInk)
                    .contentTransition(.numericText(value: Double(count)))
                    .scaleEffect(pulse ? 1.04 : 1)
                Text("of \(target)")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                if rounds > 0 {
                    Text(rounds == 1 ? String(localized: "1 round complete") : String(localized: "\(rounds) rounds complete"))
                        .font(.plCaption)
                        .foregroundStyle(Color.plGilt)
                        .accessibilityIdentifier("counter.rounds")
                }
            }
        }
        .frame(maxWidth: 320, maxHeight: 320)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(count) of \(target)"))
        .accessibilityIdentifier("counter.count")
    }

    private var controls: some View {
        VStack(spacing: PLSpacing.m) {
            Text("Tap anywhere to count")
                .font(.plCaption)
                .foregroundStyle(Color.plInkSecondary)
            HStack(spacing: PLSpacing.xs) {
                ForEach(targets, id: \.self) { value in
                    PLChip("\(value)", isSelected: target == value) {
                        target = value
                        count = 0
                    }
                    .accessibilityIdentifier("counter.target.\(value)")
                }
            }
            HStack(spacing: PLSpacing.xl) {
                Button {
                    if count > 0 { count -= 1 }
                } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .buttonStyle(.plQuiet(.plInkSecondary))
                    .disabled(count == 0)
                Button {
                    count = 0
                    rounds = 0
                } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(.plQuiet(.plInkSecondary))
                    .disabled(count == 0 && rounds == 0)
            }
        }
    }

    private func advance() {
        withAnimation(.snappy(duration: 0.18)) {
            if count + 1 >= target {
                count = 0
                rounds += 1
            } else {
                count += 1
            }
            pulse.toggle()
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.2)) { pulse = false }
        }
    }

    static func defaultTargets(including target: Int) -> [Int] {
        let base = [108, 54, 27, 11]
        return base.contains(target) ? base : [target] + base.prefix(3)
    }
}

/// Beads around a circle; counted beads glow in gilt, the guru bead (meru) sits at the top.
private struct BeadRing: View {
    let total: Int
    let filled: Int

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2 - 10
            let bead = max(3, min(9, (2 * .pi * radius) / CGFloat(max(total, 1)) * 0.55))
            ZStack {
                ForEach(0..<total, id: \.self) { index in
                    let angle = Angle.degrees(Double(index) / Double(total) * 360 - 90 + 360 / Double(total) / 2)
                    Circle()
                        .fill(index < filled ? Color.plGilt : Color.plInkSecondary.opacity(0.18))
                        .frame(width: bead, height: bead)
                        .offset(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
                }
                Circle()
                    .fill(Color.plAccent)
                    .frame(width: bead * 1.9, height: bead * 1.9)
                    .offset(y: -radius)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}
