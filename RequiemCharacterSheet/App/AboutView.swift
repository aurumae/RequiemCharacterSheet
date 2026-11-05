//
//  AboutView.swift
//  RequiemCharacterSheet
//

import SwiftUI

/// The legal notices shown on the splash screen and again in About.
enum LegalNotice {
    static let paradox = "Portions of the materials are the copyrights and trademarks of Paradox Interactive AB, and are used with permission. All rights reserved. For more information please visit worldofdarkness.com."
    static let darkPack = "This is unofficial Fan Content permitted under the Dark Pack. This app is not official World of Darkness material."
}

/// A font bundled with the app, and the licence file beside it in Fonts/.
private struct BundledFont: Identifiable {
    let name: String
    let author: String
    let licenseFile: String

    var id: String { name }

    /// Every font the app bundles. Each is under the SIL Open Font License, which asks that its licence ship with it.
    static let all = [
        BundledFont(name: "IM Fell English", author: "Igino Marini", licenseFile: "IMFellEnglish-OFL"),
        BundledFont(name: "Cinzel", author: "Natanael Gama and The Cinzel Project Authors", licenseFile: "Cinzel-OFL"),
    ]
}

/// The app's version, the Dark Pack notice, and the licenses of the bundled fonts.
struct AboutView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var appName: String {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String ?? "Character Sheet"
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(marketing) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appName)
                            .themedText(.label)
                        Text(version)
                            .themedText(.detail)
                            .foregroundStyle(theme.muted)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }

                Section(header: Text("Licenses").themedText(.subsectionHeader)) {
                    NavigationLink {
                        DarkPackNoticeView()
                            .doneButton { dismiss() }
                    } label: {
                        Text("Dark Pack")
                            .themedText(.traitName)
                    }
                }

                Section(header: Text("Fonts").themedText(.subsectionHeader)) {
                    ForEach(BundledFont.all) { font in
                        NavigationLink {
                            FontLicenseView(font: font)
                                .doneButton { dismiss() }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(font.name)
                                    .themedText(.traitName)
                                Text("SIL Open Font License 1.1 · \(font.author)")
                                    .themedText(.detail)
                                    .foregroundStyle(theme.muted)
                            }
                        }
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .doneButton { dismiss() }
        }
        .tint(theme.accent)
    }
}

private extension View {
    /// Closes About from any of its pages, not just the first.
    func doneButton(_ close: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: close)
            }
        }
    }
}

/// The Dark Pack logo and notice, as on the splash screen.
private struct DarkPackNoticeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("darkpack_logo2")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .accessibilityLabel("Dark Pack logo")
                Text(LegalNotice.paradox)
                Text(LegalNotice.darkPack)
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding()
        }
        .navigationTitle("Dark Pack")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A paragraph of a license file, or one of its section headings.
private struct LicenseParagraph {
    let text: String
    let isHeading: Bool
}

/// A font's license, read from the file bundled with it.
private struct FontLicenseView: View {
    let font: BundledFont

    private var paragraphs: [LicenseParagraph] {
        guard let url = Bundle.main.url(forResource: font.licenseFile, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [LicenseParagraph(text: "The license file is missing from this copy of the app.", isHeading: false)]
        }
        return Self.paragraphs(of: text)
    }

    /// The file is wrapped at about 78 characters; joining each paragraph's lines lets it reflow to the screen.
    /// All-capitals lines such as "PREAMBLE" stay as headings, and lines of dashes, which only separate
    /// sections in the file, are dropped.
    static func paragraphs(of text: String) -> [LicenseParagraph] {
        var result: [LicenseParagraph] = []
        for block in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n\n") {
            var lines: [String] = []
            for line in block.split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                if line.isEmpty || line.allSatisfy({ $0 == "-" }) { continue }
                if line == line.uppercased(), line.contains(where: \.isLetter), line.count < 40, !line.hasSuffix(".") {
                    if !lines.isEmpty { result.append(LicenseParagraph(text: lines.joined(separator: " "), isHeading: false)) }
                    lines = []
                    result.append(LicenseParagraph(text: line, isHeading: true))
                } else {
                    lines.append(line)
                }
            }
            if !lines.isEmpty { result.append(LicenseParagraph(text: lines.joined(separator: " "), isHeading: false)) }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph.text)
                        .fontWeight(paragraph.isHeading ? .semibold : .regular)
                        .padding(.top, paragraph.isHeading ? 8 : 0)
                        .accessibilityAddTraits(paragraph.isHeading ? .isHeader : [])
                }
            }
            .font(.footnote)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(font.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
