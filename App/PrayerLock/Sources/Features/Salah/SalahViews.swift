import PLCalendar
import PLDesign
import SwiftUI

/// Today's card for Muslims: the next prayer with a live countdown, and the Qibla.
struct SalahCard: View {
    @Environment(AppModel.self) private var model
    @State private var showingTimes = false
    @State private var showingQibla = false

    var body: some View {
        let salah = model.salah
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            if salah.settings.place == nil {
                VStack(alignment: .leading, spacing: PLSpacing.xs) {
                    Text("Salah").plEyebrow()
                    Text("Prayer times and Qibla")
                        .font(.plTitle)
                        .foregroundStyle(Color.plInk)
                    Text("Calculated on your iPhone from your approximate location. It never leaves this device.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LocateButton()
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    nextPrayer(at: context.date)
                }
                HStack(spacing: PLSpacing.s) {
                    Button { showingTimes = true } label: {
                        Label("All times", systemImage: "list.bullet")
                    }
                    .buttonStyle(.plSecondary)
                    .accessibilityIdentifier("salah.times")
                    Button { showingQibla = true } label: {
                        Label("Qibla", systemImage: "location.north.line")
                    }
                    .buttonStyle(.plSecondary)
                    .accessibilityIdentifier("salah.qibla")
                }
            }
        }
        .plPaper()
        .sheet(isPresented: $showingTimes) { SalahTimesView().environment(model) }
        .fullScreenCover(isPresented: $showingQibla) { QiblaView().environment(model) }
    }

    @ViewBuilder
    private func nextPrayer(at now: Date) -> some View {
        let salah = model.salah
        if let next = salah.nextPrayer(after: now) {
            HStack(alignment: .center, spacing: PLSpacing.m) {
                VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                    Text(salah.settings.place?.name.map { String(localized: "Next prayer · \($0)") } ?? String(localized: "Next prayer"))
                        .plEyebrow()
                    Text(next.prayer.displayName)
                        .font(.plDisplay)
                        .foregroundStyle(Color.plInk)
                        .accessibilityIdentifier("salah.next")
                    Text("\(next.time.formatted(date: .omitted, time: .shortened)) · \(Self.countdown(from: now, to: next.time))")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: next.prayer.symbol)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.plGilt)
                    .accessibilityHidden(true)
            }
            if let times = salah.times(on: now) {
                HStack(spacing: 0) {
                    ForEach(PrayerTimes.Prayer.allCases.filter(\.isPrayer)) { prayer in
                        let isNext = prayer == next.prayer && Calendar.current.isDate(next.time, inSameDayAs: now)
                        VStack(spacing: 2) {
                            Text(prayer.displayName)
                                .font(.plLabel)
                                .foregroundStyle(isNext ? Color.plAccent : Color.plInkSecondary)
                            Text(times.time(prayer)?.formatted(.dateTime.hour().minute()) ?? "–")
                                .font(.footnote.monospacedDigit())
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .foregroundStyle(isNext ? Color.plInk : Color.plInkSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    static func countdown(from now: Date, to time: Date) -> String {
        let minutes = max(0, Int(time.timeIntervalSince(now) / 60))
        if minutes < 1 { return String(localized: "now") }
        let hours = minutes / 60, rest = minutes % 60
        return hours > 0 ? String(localized: "in \(hours) h \(rest) min") : String(localized: "in \(rest) min")
    }
}

private struct LocateButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let salah = model.salah
        VStack(alignment: .leading, spacing: PLSpacing.xs) {
            Button {
                Task { await salah.locate() }
            } label: {
                if salah.locationState == .locating {
                    ProgressView()
                } else {
                    Label(salah.settings.place == nil ? "Use my location" : "Update location", systemImage: "location")
                }
            }
            .buttonStyle(.plPrimary)
            .disabled(salah.locationState == .locating)
            .accessibilityIdentifier("salah.locate")
            switch salah.locationState {
            case .denied:
                Text("Location is off for Beloved. You can allow it in the Settings app.")
                    .font(.plCaption)
                    .foregroundStyle(Color.plCaution)
            case .failed:
                Text("Couldn't find your location just now. Please try again.")
                    .font(.plCaption)
                    .foregroundStyle(Color.plCaution)
            default: EmptyView()
            }
        }
    }
}

/// The day's full timetable, how it's calculated, and reminders.
struct SalahTimesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date.now

    var body: some View {
        let salah = model.salah
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous day")
                        Spacer()
                        Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.plHeadline)
                        Spacer()
                        Button { shift(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next day")
                    }
                    .buttonStyle(.borderless)
                    if let times = salah.times(on: day) {
                        ForEach(PrayerTimes.Prayer.allCases) { prayer in
                            HStack {
                                Label(prayer.displayName, systemImage: prayer.symbol)
                                    .foregroundStyle(prayer.isPrayer ? Color.plInk : Color.plInkSecondary)
                                Spacer()
                                Text(times.time(prayer)?.formatted(date: .omitted, time: .shortened) ?? "–")
                                    .monospacedDigit()
                                    .foregroundStyle(prayer.isPrayer ? Color.plInk : Color.plInkSecondary)
                            }
                        }
                    }
                } footer: {
                    if let name = salah.settings.place?.name { Text("For \(name).") }
                }

                Section {
                    Toggle("Remind me at each prayer", isOn: Binding(
                        get: { salah.settings.remindersOn },
                        set: { on in Task { _ = await salah.setReminders(on) } }
                    ))
                    .accessibilityIdentifier("salah.reminders")
                } footer: {
                    Text("A gentle notification when each prayer's time begins.")
                }

                Section {
                    Picker("Calculation", selection: Binding(get: { salah.settings.method }, set: { salah.setMethod($0) })) {
                        ForEach(PrayerCalculationMethod.allCases) { Text($0.name).tag($0) }
                    }
                    Picker("Asr", selection: Binding(get: { salah.settings.asr }, set: { salah.setAsr($0) })) {
                        ForEach(AsrSchool.allCases) { Text($0.name).tag($0) }
                    }
                    LocateButton()
                        .listRowBackground(Color.clear)
                } header: {
                    Text("How times are calculated")
                } footer: {
                    Text("Times are calculated from the sun's position and can differ by a few minutes from your mosque's timetable. Follow your local mosque where they differ.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.plCanvas)
            .navigationTitle("Prayer times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationBackground(Color.plCanvas)
    }

    private func shift(_ days: Int) {
        day = Calendar.current.date(byAdding: .day, value: days, to: day) ?? day
    }
}

/// A compass that points to the Kaaba, with a soft tap when you're facing it.
struct QiblaView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let salah = model.salah
        let bearing = salah.qiblaBearing ?? 0
        let heading = salah.heading
        let offset = heading.map { Self.signedDifference(bearing, $0) }
        let facing = offset.map { abs($0) < 5 } ?? false
        ZStack {
            Color.plCanvas.ignoresSafeArea()
            VStack(spacing: PLSpacing.xl) {
                HStack {
                    VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                        Text("Qibla").plEyebrow()
                        Text(facing ? String(localized: "You're facing the Qibla") : String(localized: "Turn toward the Kaaba"))
                            .font(.plTitle)
                            .foregroundStyle(facing ? Color.plAccent : Color.plInk)
                            .accessibilityIdentifier("qibla.status")
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plQuiet(.plAccent))
                }
                Spacer()
                ZStack {
                    // The dial turns with the phone so north stays north.
                    CompassDial()
                        .rotationEffect(.degrees(-(heading ?? 0)))
                    // The Qibla needle.
                    VStack(spacing: 0) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(facing ? Color.plAccent : Color.plGilt)
                        Rectangle()
                            .fill((facing ? Color.plAccent : Color.plGilt).opacity(0.6))
                            .frame(width: 3, height: 90)
                        Spacer()
                    }
                    .frame(height: 260)
                    .rotationEffect(.degrees(bearing - (heading ?? 0)))
                    Image(systemName: "cube.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.plInk)
                        .accessibilityHidden(true)
                }
                .frame(width: 300, height: 300)
                .animation(.easeOut(duration: 0.25), value: heading)
                .sensoryFeedback(.success, trigger: facing) { _, new in new }
                VStack(spacing: PLSpacing.xs) {
                    Text("\(Int(bearing.rounded()))° from true north")
                        .font(.plHeadline)
                        .foregroundStyle(Color.plInk)
                        .accessibilityIdentifier("qibla.bearing")
                    if let distance = salah.qiblaDistance {
                        Text("Makkah is \(Int(distance).formatted()) km away")
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                    }
                    if !salah.headingAvailable {
                        Text("This device has no compass. Face \(Int(bearing.rounded()))° clockwise from north.")
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                            .multilineTextAlignment(.center)
                    } else if let accuracy = salah.headingAccuracy, accuracy < 0 || accuracy > 25 {
                        Text("Move your iPhone in a figure-eight to calibrate the compass. Keep away from metal and magnets.")
                            .font(.plCaption)
                            .foregroundStyle(Color.plCaution)
                            .multilineTextAlignment(.center)
                    }
                }
                Spacer()
            }
            .padding(PLSpacing.page)
        }
        .onAppear { salah.startHeading() }
        .onDisappear { salah.stopHeading() }
    }

    static func signedDifference(_ target: Double, _ heading: Double) -> Double {
        var diff = (target - heading).truncatingRemainder(dividingBy: 360)
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        return diff
    }
}

private struct CompassDial: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(Color.plInkSecondary.opacity(0.25), lineWidth: 1)
            ForEach(0..<72, id: \.self) { tick in
                Rectangle()
                    .fill(Color.plInkSecondary.opacity(tick % 18 == 0 ? 0.8 : 0.3))
                    .frame(width: tick % 18 == 0 ? 2 : 1, height: tick % 18 == 0 ? 14 : 7)
                    .offset(y: -142)
                    .rotationEffect(.degrees(Double(tick) * 5))
            }
            ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { index, letter in
                Text(letter)
                    .font(.plLabel)
                    .foregroundStyle(index == 0 ? Color.plCaution : Color.plInkSecondary)
                    .offset(y: -118)
                    .rotationEffect(.degrees(Double(index) * 90))
            }
        }
        .accessibilityHidden(true)
    }
}
