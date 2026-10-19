import PLCalendar
import PLDesign
import SwiftUI

// MARK: - Ramadan

extension AppModel {
    /// The day of Ramadan (1–30) when today falls in it, by the Umm al-Qura estimate.
    var ramadanDay: Int? {
        guard profile.faithID?.rawValue == "islam",
              let ramadan = todaysObservances().first(where: { $0.occasionID == "islam.ramadan" }) else { return nil }
        return ramadan.range.start.days(until: today) + 1
    }
}

/// During Ramadan, on Today: when suhoor ends and when to break the fast.
struct RamadanCard: View {
    @Environment(AppModel.self) private var model
    let day: Int

    var body: some View {
        PLHeroCard {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(alignment: .leading, spacing: PLSpacing.m) {
                    HStack {
                        Text(String(localized: "Ramadan · day \(day)")).plHeroEyebrow()
                        Spacer()
                        Image(systemName: "moon.stars.fill").font(.title2).accessibilityHidden(true)
                    }
                    if let times = model.salah.times(on: context.date), let fajr = times.time(.fajr), let maghrib = times.time(.maghrib) {
                        let fasting = context.date >= fajr && context.date < maghrib
                        Text(fasting ? String(localized: "Iftar at \(maghrib.formatted(date: .omitted, time: .shortened))") : String(localized: "Suhoor ends at \(nextFajr(after: context.date, today: fajr).formatted(date: .omitted, time: .shortened))"))
                            .font(.system(.largeTitle, design: .serif))
                            .accessibilityIdentifier("ramadan.next")
                        Text(fasting ? countdown(to: maghrib, from: context.date) : String(localized: "Fajr begins the fast. Iftar today: \(maghrib.formatted(date: .omitted, time: .shortened))"))
                            .font(.system(.callout, design: .serif))
                            .opacity(0.9)
                    } else {
                        Text("Ramadan Mubarak").font(.system(.largeTitle, design: .serif))
                        Text("Add your location under Prayer times to see suhoor and iftar.")
                            .font(.system(.callout, design: .serif)).opacity(0.9)
                    }
                }
            }
        }
    }

    private func nextFajr(after now: Date, today fajr: Date) -> Date {
        if now < fajr { return fajr }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        return model.salah.times(on: tomorrow)?.time(.fajr) ?? fajr
    }

    private func countdown(to time: Date, from now: Date) -> String {
        let minutes = max(0, Int(time.timeIntervalSince(now) / 60))
        return minutes >= 60 ? String(localized: "\(minutes / 60) h \(minutes % 60) min to iftar") : String(localized: "\(minutes) min to iftar")
    }
}

// MARK: - Zakat

/// A simple zakat calculator: 2.5% of zakatable wealth held for a lunar year, when it is at
/// least the nisab. Amounts stay on this screen.
struct ZakatCalculatorView: View {
    enum Standard: String, CaseIterable, Identifiable {
        case gold, silver
        var id: String { rawValue }
        /// Commonly used nisab weights; some scholars use 87.48 g of gold and 612.36 g of silver.
        var grams: Double { self == .gold ? 85 : 595 }
    }

    @State private var standard: Standard = .silver
    @State private var pricePerGram: Double?
    @State private var cash: Double?
    @State private var gold: Double?
    @State private var silver: Double?
    @State private var investments: Double?
    @State private var business: Double?
    @State private var owedToYou: Double?
    @State private var debts: Double?

    private var currency: String { Locale.current.currency?.identifier ?? "USD" }
    private var total: Double { [cash, gold, silver, investments, business, owedToYou].compactMap { $0 }.reduce(0, +) - (debts ?? 0) }
    private var nisab: Double? { pricePerGram.map { $0 * standard.grams } }
    private var due: Double? {
        guard let nisab, total >= nisab, total > 0 else { return nil }
        return total * 0.025
    }

    var body: some View {
        Form {
            Section {
                Picker("Nisab standard", selection: $standard) {
                    Text("Silver (595 g)").tag(Standard.silver)
                    Text("Gold (85 g)").tag(Standard.gold)
                }
                amount("Price of \(standard.rawValue) per gram", $pricePerGram)
            } header: {
                Text("Nisab")
            } footer: {
                Text("Many scholars recommend the silver standard, which reaches more people in need. Use today's local price.")
            }
            Section("What you own") {
                amount("Cash and bank balances", $cash)
                amount("Gold (value)", $gold)
                amount("Silver (value)", $silver)
                amount("Shares and investments", $investments)
                amount("Business stock", $business)
                amount("Money owed to you", $owedToYou)
            }
            Section("What you owe") {
                amount("Debts due now", $debts)
            }
            Section {
                LabeledContent("Zakatable wealth", value: total.formatted(.currency(code: currency)))
                if let nisab {
                    LabeledContent("Nisab", value: nisab.formatted(.currency(code: currency)))
                }
                if let due {
                    LabeledContent("Zakat due (2.5%)") {
                        Text(due.formatted(.currency(code: currency)))
                            .font(.plTitleSmall)
                            .foregroundStyle(Color.plAccent)
                            .accessibilityIdentifier("zakat.due")
                    }
                } else if nisab != nil {
                    Text("Below the nisab — no zakat is due on this wealth.")
                        .foregroundStyle(Color.plInkSecondary)
                } else {
                    Text("Enter the price per gram to find the nisab.")
                        .foregroundStyle(Color.plInkSecondary)
                }
            } footer: {
                Text("Zakat is due on wealth above the nisab held for one lunar year. This is a guide; for jewellery, pensions, property or business questions, ask a trusted scholar.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.plCanvas)
        .navigationTitle("Zakat calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func amount(_ title: String, _ value: Binding<Double?>) -> some View {
        LabeledContent(title) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }
}
