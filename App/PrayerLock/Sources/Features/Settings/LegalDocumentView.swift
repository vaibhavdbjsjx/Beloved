import PLCore
import PLDesign
import SwiftUI

/// Shows a legal document bundled with the app (readable offline, so the in-app
/// privacy policy link always works — App Review Guideline 5.1.1(i)).
struct LegalDocumentView: View {
    let resource: BundledDocument

    var body: some View {
        ScrollView {
            if let document = resource.load() {
                VStack(alignment: .leading, spacing: PLSpacing.m) {
                    ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                        view(for: block)
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, PLSpacing.page)
                .padding(.vertical, PLSpacing.l)
                .textSelection(.enabled)
            } else {
                // Only reachable if the build is missing the file (a packaging defect).
                ContentUnavailableView(
                    "This document couldn't be opened",
                    systemImage: "doc.questionmark",
                    description: Text("Please update \(AppBrand.displayName). You can also read it from the link on the App Store page.")
                )
                .padding(.top, PLSpacing.xxl)
            }
        }
        .background(Color.plCanvas)
        .navigationTitle(resource.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func view(for block: LegalDocument.Block) -> some View {
        switch block {
        case let .title(text):
            Text(inline(text))
                .font(.plDisplay)
                .foregroundStyle(Color.plInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        case let .heading(text):
            VStack(alignment: .leading, spacing: PLSpacing.s) {
                PLHairline()
                Text(inline(text))
                    .font(.plTitleSmall)
                    .foregroundStyle(Color.plInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, PLSpacing.m)
            .accessibilityAddTraits(.isHeader)
        case let .subheading(text):
            Text(inline(text))
                .font(.headline)
                .foregroundStyle(Color.plInk)
                .accessibilityAddTraits(.isHeader)
        case let .paragraph(text):
            Text(inline(text))
                .font(.plBody)
                .lineSpacing(4)
                .foregroundStyle(Color.plInk)
                .fixedSize(horizontal: false, vertical: true)
        case let .bullet(text):
            HStack(alignment: .firstTextBaseline, spacing: PLSpacing.s) {
                Rectangle()
                    .fill(Color.plGilt)
                    .frame(width: 5, height: 5)
                    .rotationEffect(.degrees(45))
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
                    .accessibilityHidden(true)
                Text(inline(text))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.plBody)
            .foregroundStyle(Color.plInk)
        }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// Documents shipped inside the app bundle.
enum BundledDocument {
    case privacyPolicy

    var title: String {
        switch self {
        case .privacyPolicy: String(localized: "Privacy Policy")
        }
    }

    private var resourceName: String {
        switch self {
        case .privacyPolicy: "PrivacyPolicy"
        }
    }

    func load(bundle: Bundle = .main) -> LegalDocument? {
        let url = bundle.url(forResource: resourceName, withExtension: "md")
            ?? bundle.url(forResource: resourceName, withExtension: "md", subdirectory: "Legal")
        guard let url, let markdown = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let document = LegalDocument.parse(markdown: markdown)
        return document.blocks.isEmpty ? nil : document
    }
}
