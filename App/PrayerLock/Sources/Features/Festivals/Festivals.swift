import PLCalendar
import PLCore
import PLDesign
import SwiftUI

/// How Beloved greets someone on their own faith's holy days. Joyful feasts get a joyful
/// greeting; solemn days (Good Friday, Ashura, the Day of Arafah) a quiet one. Days that not
/// every community observes are shown in the calendar but never pushed as a notification.
struct FestivalGreeting: Equatable {
    var title: String
    var message: String
    /// What to ask the companion ("How do I celebrate Diwali at home?").
    var question: String
    var symbol: String
    var notifies: Bool = true

    var isWish: Bool {
        ["Happy", "Merry", "Mubarak", "risen"].contains { title.contains($0) }
    }

    static func forOccasion(_ id: String, name: String) -> FestivalGreeting? {
        switch id {
        // Hindu
        case "hinduism.diwali":
            FestivalGreeting(title: String(localized: "Happy Diwali"), message: String(localized: "May the light of every diya fill your home with Lakshmi's blessings, peace and joy."), question: "How do I do Lakshmi puja at home on Diwali, step by step?", symbol: "flame")
        case "hinduism.holi":
            FestivalGreeting(title: String(localized: "Happy Holi"), message: String(localized: "May your life be as bright as the colours today, and your heart as light as Prahlada's faith."), question: "What is the story of Holi and how is it celebrated?", symbol: "paintpalette")
        case "hinduism.holika-dahan":
            FestivalGreeting(title: String(localized: "Holika Dahan"), message: String(localized: "Tonight's fire remembers how devotion was protected. May every negativity burn away."), question: "How is Holika Dahan done and what is its story?", symbol: "flame")
        case "hinduism.maha-shivaratri":
            FestivalGreeting(title: String(localized: "Happy Maha Shivaratri"), message: String(localized: "Om Namah Shivaya. May Mahadev bless you with stillness, strength and grace tonight."), question: "How do I observe Maha Shivaratri — fasting, puja and the night vigil?", symbol: "moon.stars")
        case "hinduism.janmashtami":
            FestivalGreeting(title: String(localized: "Happy Janmashtami"), message: String(localized: "May Bal Gopal fill your home with joy and your heart with love. Jai Shri Krishna!"), question: "How do I celebrate Janmashtami at home, including the midnight puja?", symbol: "music.note")
        case "hinduism.ganesh-chaturthi":
            FestivalGreeting(title: String(localized: "Happy Ganesh Chaturthi"), message: String(localized: "Ganpati Bappa Morya! May Vighnaharta remove every obstacle from your path."), question: "How do I welcome Ganesha at home on Ganesh Chaturthi, step by step?", symbol: "sparkles")
        case "hinduism.rama-navami":
            FestivalGreeting(title: String(localized: "Happy Rama Navami"), message: String(localized: "Jai Shri Ram. May Maryada Purushottam guide you in truth and duty."), question: "How is Rama Navami celebrated and what should I do at home?", symbol: "sun.max")
        case "hinduism.navaratri":
            FestivalGreeting(title: String(localized: "Happy Navaratri"), message: String(localized: "May the Divine Mother bless you with strength, wisdom and prosperity through these nine nights."), question: "How do I observe Navaratri — ghatasthapana, daily puja and fasting?", symbol: "sparkles")
        case "hinduism.durga-ashtami":
            FestivalGreeting(title: String(localized: "Durga Ashtami"), message: String(localized: "Jai Mata Di. May Maa Durga protect you and your family."), question: "How is Durga Ashtami observed, including kanya puja?", symbol: "sparkles")
        case "hinduism.dussehra":
            FestivalGreeting(title: String(localized: "Happy Dussehra"), message: String(localized: "May good always triumph in your life, as it did for Shri Ram."), question: "What is the story of Dussehra and how is it celebrated?", symbol: "bolt.shield")
        case "hinduism.makar-sankranti":
            FestivalGreeting(title: String(localized: "Happy Makar Sankranti"), message: String(localized: "May the sun's new journey bring warmth, harvest and sweetness to your home."), question: "How are Makar Sankranti and Pongal celebrated?", symbol: "sun.horizon")
        case "hinduism.vasant-panchami":
            FestivalGreeting(title: String(localized: "Happy Vasant Panchami"), message: String(localized: "May Maa Saraswati bless you with wisdom, learning and creativity."), question: "How do I do Saraswati puja on Vasant Panchami?", symbol: "book")
        case "hinduism.new-year":
            FestivalGreeting(title: String(localized: "Happy New Year"), message: String(localized: "Happy Ugadi, Gudi Padwa and Chaitra Navratri — may the new year be auspicious for you."), question: "How are Ugadi and Gudi Padwa celebrated, and how do I begin Chaitra Navratri?", symbol: "leaf")
        case "hinduism.rath-yatra":
            FestivalGreeting(title: String(localized: "Happy Rath Yatra"), message: String(localized: "Jai Jagannath! May the Lord of the Universe draw you close."), question: "What is the meaning of Rath Yatra and how can I take part from home?", symbol: "figure.walk")
        case "hinduism.onam":
            FestivalGreeting(title: String(localized: "Happy Onam"), message: String(localized: "May Mahabali's visit bring abundance, unity and joy to your home."), question: "What is the story of Onam and how is it celebrated?", symbol: "leaf")
        case "hinduism.raksha-bandhan":
            FestivalGreeting(title: String(localized: "Happy Raksha Bandhan"), message: String(localized: "May the thread of love and protection between siblings stay strong forever."), question: "How is the Raksha Bandhan ritual done?", symbol: "heart")
        case "hinduism.karwa-chauth":
            FestivalGreeting(title: String(localized: "Karwa Chauth"), message: String(localized: "May your fast be blessed and your bond be long and loving."), question: "How is the Karwa Chauth fast and puja done?", symbol: "moon")
        case "hinduism.naraka-chaturdashi":
            FestivalGreeting(title: String(localized: "Happy Naraka Chaturdashi"), message: String(localized: "May the light of Choti Diwali drive every darkness from your life."), question: "How is Naraka Chaturdashi (Choti Diwali) observed?", symbol: "flame")
        case "hinduism.govardhan-puja":
            FestivalGreeting(title: String(localized: "Happy Govardhan Puja"), message: String(localized: "May Shri Krishna shelter you as he sheltered Gokul."), question: "How is Govardhan Puja and Annakut done?", symbol: "mountain.2")
        case "hinduism.bhai-dooj":
            FestivalGreeting(title: String(localized: "Happy Bhai Dooj"), message: String(localized: "Blessings to every brother and sister today."), question: "How is the Bhai Dooj tilak ceremony done?", symbol: "heart")
        case "hinduism.chhath":
            FestivalGreeting(title: String(localized: "Chhath Puja"), message: String(localized: "May Surya Dev and Chhathi Maiya bless your family with health and long life."), question: "How is Chhath Puja observed over its four days?", symbol: "sunrise")
        // Christian
        case "christianity.christmas", "christianity.christmas-julian":
            FestivalGreeting(title: String(localized: "Merry Christmas"), message: String(localized: "Christ is born! May the peace of the Christ child fill your heart and home."), question: "What is the meaning of Christmas and how can my family keep it holy?", symbol: "star")
        case "christianity.christmas-eve":
            FestivalGreeting(title: String(localized: "Christmas Eve"), message: String(localized: "Tonight we wait for the light of the world."), question: "What are good ways to pray on Christmas Eve?", symbol: "star")
        case "christianity.easter":
            FestivalGreeting(title: String(localized: "Happy Easter"), message: String(localized: "He is risen! May the joy of the resurrection fill your life."), question: "What does Easter mean and how do Christians celebrate it?", symbol: "sunrise")
        case "christianity.pascha":
            FestivalGreeting(title: String(localized: "Christ is risen!"), message: String(localized: "Truly He is risen! A joyful Pascha to you and your family."), question: "How is Orthodox Pascha celebrated?", symbol: "sunrise")
        case "christianity.good-friday", "christianity.holy-friday-orthodox":
            FestivalGreeting(title: String(localized: "Good Friday"), message: String(localized: "Today we remember the love that went to the cross. Take a quiet moment at the foot of it."), question: "How can I observe Good Friday prayerfully?", symbol: "cross")
        case "christianity.holy-thursday":
            FestivalGreeting(title: String(localized: "Holy Thursday"), message: String(localized: "The Last Supper and the washing of the feet: love that serves."), question: "What happened on Holy Thursday and how is it observed?", symbol: "cup.and.saucer")
        case "christianity.palm-sunday":
            FestivalGreeting(title: String(localized: "Palm Sunday"), message: String(localized: "Hosanna! Holy Week begins."), question: "What is Palm Sunday and how should I walk through Holy Week?", symbol: "leaf")
        case "christianity.ash-wednesday":
            FestivalGreeting(title: String(localized: "Ash Wednesday"), message: String(localized: "Lent begins: forty days of prayer, fasting and giving."), question: "What should I give up or take on for Lent, and how does Ash Wednesday work?", symbol: "drop")
        case "christianity.pentecost", "christianity.pentecost-orthodox":
            FestivalGreeting(title: String(localized: "Happy Pentecost"), message: String(localized: "Come, Holy Spirit. May His fire renew your faith."), question: "What happened at Pentecost?", symbol: "flame")
        case "christianity.epiphany":
            FestivalGreeting(title: String(localized: "Happy Epiphany"), message: String(localized: "Like the Magi, may you find Christ and bring Him your gifts."), question: "What is Epiphany and how is it celebrated?", symbol: "star")
        case "christianity.ascension":
            FestivalGreeting(title: String(localized: "Ascension Day"), message: String(localized: "Christ ascended, and is with us always."), question: "What is the Ascension and why does it matter?", symbol: "arrow.up.circle")
        case "christianity.annunciation":
            FestivalGreeting(title: String(localized: "The Annunciation"), message: String(localized: "Mary's yes to God — may we say yes too."), question: "What is the Feast of the Annunciation?", symbol: "sparkles")
        case "christianity.assumption":
            FestivalGreeting(title: String(localized: "The Assumption"), message: String(localized: "A blessed feast of Our Lady to you."), question: "What is the Assumption of Mary?", symbol: "sparkles")
        case "christianity.all-saints":
            FestivalGreeting(title: String(localized: "All Saints' Day"), message: String(localized: "We give thanks for the great cloud of witnesses."), question: "What is All Saints' Day and how is it kept?", symbol: "person.3")
        case "christianity.advent":
            FestivalGreeting(title: String(localized: "Advent begins"), message: String(localized: "A season of waiting and hope. Light the first candle."), question: "How do I keep Advent at home, with a wreath and daily prayer?", symbol: "flame")
        case "christianity.lent":
            FestivalGreeting(title: String(localized: "Lent"), message: String(localized: "Forty days to draw closer to God."), question: "How can I keep a good Lent?", symbol: "drop", notifies: false)
        // Islam
        case "islam.ramadan":
            FestivalGreeting(title: String(localized: "Ramadan Mubarak"), message: String(localized: "May Allah accept your fasts and prayers, and make this month a light for you."), question: "How do I make the most of Ramadan — fasting rules, taraweeh and duas?", symbol: "moon.stars")
        case "islam.eid-al-fitr":
            FestivalGreeting(title: String(localized: "Eid Mubarak"), message: String(localized: "Taqabbal Allahu minna wa minkum. May Allah accept from us and from you."), question: "What is the sunnah way to celebrate Eid al-Fitr, including Zakat al-Fitr and the Eid prayer?", symbol: "moon.stars")
        case "islam.eid-al-adha":
            FestivalGreeting(title: String(localized: "Eid al-Adha Mubarak"), message: String(localized: "May Allah accept your sacrifice and bless your family."), question: "How is Eid al-Adha observed, including the Eid prayer and qurbani?", symbol: "moon.stars")
        case "islam.day-of-arafah":
            FestivalGreeting(title: String(localized: "The Day of Arafah"), message: String(localized: "The best day for du'a. Many fast today — make your du'as count."), question: "What should I do on the Day of Arafah?", symbol: "hands.sparkles")
        case "islam.last-ten-nights":
            FestivalGreeting(title: String(localized: "The last ten nights"), message: String(localized: "Seek Laylat al-Qadr in the odd nights. May Allah grant you its blessing."), question: "How do I make the most of the last ten nights of Ramadan?", symbol: "moon.stars")
        case "islam.laylat-al-qadr":
            FestivalGreeting(title: String(localized: "Laylat al-Qadr"), message: String(localized: "The Night of Power, better than a thousand months. Pray, recite and ask."), question: "What is Laylat al-Qadr and how should I spend the night?", symbol: "sparkles", notifies: false)
        case "islam.new-year":
            FestivalGreeting(title: String(localized: "A new Hijri year"), message: String(localized: "May Allah make the new year one of faith, peace and blessing."), question: "What is the significance of the Islamic new year and the month of Muharram?", symbol: "moon")
        case "islam.ashura":
            FestivalGreeting(title: String(localized: "Ashura"), message: String(localized: "A day of remembrance. Many fast today; Shia Muslims mourn Imam Husayn."), question: "What is Ashura and how is it observed?", symbol: "moon", notifies: false)
        case "islam.isra-miraj":
            FestivalGreeting(title: String(localized: "Isra and Mi'raj"), message: String(localized: "Remembering the Night Journey."), question: "What happened during the Isra and Mi'raj?", symbol: "moon.stars", notifies: false)
        case "islam.mawlid":
            FestivalGreeting(title: String(localized: "Mawlid an-Nabi"), message: String(localized: "Remembering the Prophet (peace be upon him)."), question: "What is the Mawlid and why do some Muslims celebrate it while others don't?", symbol: "moon.stars", notifies: false)
        default:
            nil
        }
    }
}

extension AppModel {
    /// Holy days ahead in the user's own calendar (never another faith's), weekly days excluded.
    func upcomingObservances(days: Int) -> [Observance] {
        let range = CivilDateRange(start: today, end: today.adding(days: days))
        return env.religiousCalendar.observances(in: range, faith: profile.faithID, tradition: profile.traditionID)
            .filter { $0.definition.kind != .weekly && $0.range.end >= today }
    }

    /// The festival to celebrate on Today: one that starts today, else the next within a week.
    var featuredFestival: (observance: Observance, greeting: FestivalGreeting, daysAway: Int)? {
        for observance in upcomingObservances(days: 7) {
            // A season already under way (Lent, Navaratri) was greeted on its first day; it
            // stays in the calendar and the "In the calendar" list.
            let daysAway = today.days(until: observance.range.start)
            guard daysAway >= 0 else { continue }
            if let greeting = FestivalGreeting.forOccasion(observance.occasionID.rawValue, name: observance.definition.name.resolved(for: profile.languages)) {
                return (observance, greeting, daysAway)
            }
        }
        return nil
    }

    /// Greets the user on the morning of each of their holy days (8 am), if notifications
    /// are allowed. Never asks for permission by itself.
    func rescheduleFestivalGreetings() async {
        guard festivalGreetingsEnabled, isOnboarded,
              await env.notifications.authorizationStatus() == .authorized else {
            await env.notifications.removeFestivals()
            return
        }
        let firstName = profile.displayName?.split(separator: " ").first.map(String.init)
        var reminders: [(id: String, date: Date, title: String, body: String)] = []
        for observance in upcomingObservances(days: 200) where observance.range.start >= today {
            guard let greeting = FestivalGreeting.forOccasion(observance.occasionID.rawValue, name: observance.definition.name.resolved(for: profile.languages)),
                  greeting.notifies,
                  let morning = env.calendar.date(from: DateComponents(year: observance.range.start.year, month: observance.range.start.month, day: observance.range.start.day, hour: 8)),
                  morning > .now else { continue }
            let title = greeting.isWish ? (firstName.map { "\(greeting.title), \($0)" } ?? greeting.title) : greeting.title
            reminders.append((id: observance.id, date: morning, title: title, body: greeting.message))
            if reminders.count >= 12 { break }
        }
        await env.notifications.scheduleFestivals(reminders)
    }

    /// Opens the companion with a question already asked.
    func ask(_ question: String) {
        pendingCompanionQuestion = question
        selectedTab = .companion
    }
}

enum FestivalSettings {
    static let key = "pl.festivalGreetings"
}

extension AppModel {
    /// On by default: a greeting on the morning of the user's own holy days.
    var festivalGreetingsEnabled: Bool {
        get { env.preferences.object(forKey: FestivalSettings.key) as? Bool ?? true }
        set { env.preferences.set(newValue, forKey: FestivalSettings.key) }
    }
}

// MARK: - Today banner

/// The day's festival, in the faith's jewel tone: a greeting, and how to celebrate.
struct FestivalBanner: View {
    @Environment(AppModel.self) private var model
    let observance: Observance
    let greeting: FestivalGreeting
    let daysAway: Int

    var body: some View {
        let name = observance.definition.name.resolved(for: model.profile.languages)
        PLHeroCard {
            VStack(alignment: .leading, spacing: PLSpacing.m) {
                HStack(alignment: .top) {
                    Text(daysAway == 0 ? String(localized: "Today") : (daysAway == 1 ? String(localized: "Tomorrow") : String(localized: "In \(daysAway) days")))
                        .plHeroEyebrow()
                    Spacer()
                    Image(systemName: greeting.symbol)
                        .font(.title2)
                        .foregroundStyle(Color.plOnAccentFill.opacity(0.9))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: PLSpacing.xs) {
                    Text(daysAway == 0 ? greetingTitle : name)
                        .font(.system(.largeTitle, design: .serif, weight: .regular))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("festival.title")
                    Text(daysAway == 0 ? greeting.message : String(localized: "\(observance.range.start.formatted) — get ready with a simple guide."))
                        .font(.system(.callout, design: .serif))
                        .opacity(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    model.ask(daysAway == 0 ? greeting.question : String(localized: "How should I prepare for \(name)? \(greeting.question)"))
                } label: {
                    Label(daysAway == 0 ? String(localized: "How to celebrate") : String(localized: "How to prepare"), systemImage: "sparkles")
                        .font(.plHeadline)
                        .foregroundStyle(Color.plAccent)
                        .padding(.horizontal, PLSpacing.m)
                        .padding(.vertical, PLSpacing.s)
                        .background(Capsule().fill(Color.plOnAccentFill))
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("festival.ask")
            }
        }
    }

    /// "Happy Diwali, Vaibhav" — the name only follows a wish, never a solemn day's title.
    private var greetingTitle: String {
        guard greeting.isWish, let first = model.profile.displayName?.split(separator: " ").first else { return greeting.title }
        return "\(greeting.title), \(first)"
    }
}

extension CivilDate {
    /// "Sunday, 8 November".
    var formatted: String {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        guard let date = Calendar.current.date(from: components) else { return description }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

// MARK: - Holy days

/// The year ahead in the user's own tradition, by month.
struct HolyDaysView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let observances = model.upcomingObservances(days: 370)
        let months = Dictionary(grouping: observances) { "\($0.range.start.year)-\(String(format: "%02d", $0.range.start.month))" }
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.l) {
                Text("Festivals and holy days in your tradition. Tap one to learn how it's celebrated.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if observances.isEmpty {
                    Text("No dates are available for the year ahead yet.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                }
                ForEach(months.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        Text(monthTitle(key)).plEyebrow()
                        VStack(spacing: 0) {
                            ForEach(Array((months[key] ?? []).enumerated()), id: \.element.id) { index, observance in
                                if index > 0 { PLHairline().padding(.leading, PLSpacing.m) }
                                NavigationLink {
                                    FestivalDetailView(observance: observance)
                                } label: {
                                    HolyDayRow(observance: observance)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .plPaper(padding: 0)
                    }
                }
            }
            .padding(PLSpacing.page)
        }
        .background(Color.plCanvas)
        .navigationTitle("Holy days")
        .navigationBarTitleDisplayMode(.large)
    }

    private func monthTitle(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2, let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: 1)) else { return key }
        return date.formatted(.dateTime.month(.wide).year())
    }
}

private struct HolyDayRow: View {
    @Environment(AppModel.self) private var model
    let observance: Observance

    var body: some View {
        HStack(spacing: PLSpacing.m) {
            VStack(spacing: 0) {
                Text("\(observance.range.start.day)")
                    .font(.system(.title3, design: .serif, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.plAccent)
                Text(weekday)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.plInkSecondary)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(observance.definition.name.resolved(for: model.profile.languages))
                    .font(.plHeadline)
                    .foregroundStyle(Color.plInk)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.plInkSecondary.opacity(0.7))
        }
        .padding(.horizontal, PLSpacing.m)
        .padding(.vertical, PLSpacing.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var weekday: String {
        guard let date = Calendar.current.date(from: DateComponents(year: observance.range.start.year, month: observance.range.start.month, day: observance.range.start.day)) else { return "" }
        return date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }

    private var detail: String {
        let days = model.today.days(until: observance.range.start)
        var parts: [String] = []
        if observance.range.dayCount > 1 { parts.append(String(localized: "\(observance.range.dayCount) days")) }
        parts.append(days <= 0 ? String(localized: "Now") : (days == 1 ? String(localized: "Tomorrow") : String(localized: "In \(days) days")))
        if observance.isEstimated { parts.append(String(localized: "Expected")) }
        return parts.joined(separator: " · ")
    }
}

struct FestivalDetailView: View {
    @Environment(AppModel.self) private var model
    let observance: Observance

    var body: some View {
        let languages = model.profile.languages
        let name = observance.definition.name.resolved(for: languages)
        let greeting = FestivalGreeting.forOccasion(observance.occasionID.rawValue, name: name)
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.l) {
                PLHeroCard {
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        Text(dateLine).plHeroEyebrow()
                        Text(name)
                            .font(.system(.largeTitle, design: .serif))
                            .fixedSize(horizontal: false, vertical: true)
                        if let greeting {
                            Text(greeting.message)
                                .font(.system(.callout, design: .serif))
                                .opacity(0.9)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let note = observance.definition.note?.resolved(for: languages) {
                    Text(note)
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    PLSectionHeader(String(localized: "Ask the companion"))
                    VStack(spacing: 0) {
                        let questions = [
                            greeting?.question ?? "How is \(name) observed?",
                            "What is the story and meaning behind \(name)?",
                            "What foods, fasting or customs go with \(name)?",
                        ]
                        ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                            if index > 0 { PLHairline().padding(.leading, PLSpacing.m) }
                            PLListRow(question, systemName: index == 0 ? "sparkles" : "text.bubble") { model.ask(question) }
                        }
                    }
                    .plPaper(padding: 0)
                }
                Text("Source: \(observance.definition.source)")
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PLSpacing.page)
        }
        .background(Color.plCanvas)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dateLine: String {
        let start = observance.range.start.formatted
        let text = observance.range.dayCount > 1 ? "\(start) – \(observance.range.end.formatted)" : start
        return observance.isEstimated ? String(localized: "\(text) · expected") : text
    }
}
