// render-forsaken-headings.swift
//
// Draws Forsaken's section headings in Flat Earth Scribe as vector PDFs for the asset catalog.
//
// Flat Earth Scribe (Nate Piekos, Blambot) is licensed for desktop use only, so it must never ship in either app.
// This draws each heading's letters as filled outlines, not text, so the PDFs hold no font. Run it on a Mac with the
// font installed whenever a Forsaken section is added or renamed:
//
//     swift scripts/render-forsaken-headings.swift
//
// The app tints the images Werewolf Rust and scales them with the text size; see `SectionHeading`.

import AppKit
import CoreText

/// Every section heading the Forsaken sheet can show, as `SheetSection.heading` spells it.
let headings = [
    "Character Creation", "Character", "Form", "Advantages", "Attributes", "Skills", "Merits", "Totem", "Renown",
    "Auspice Benefit", "Moon Gifts", "Shadow Gifts", "Wolf Gifts", "Rites", "Fetishes", "Aspirations", "Health",
    "Willpower", "Primal Urge", "Harmony", "Kuruth Triggers", "Experience", "Conditions",
]

/// The size the headings are drawn at; the app scales from here. Matches Forsaken's heading text style.
let pointSize: CGFloat = 27
let output = URL(fileURLWithPath: "ForsakenCharacterSheet/Assets.xcassets/Section Headings")

guard let font = NSFont(name: "FlatEarthScribe", size: pointSize) else {
    print("Flat Earth Scribe isn't installed on this Mac.")
    exit(1)
}

func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try writeJSON(["info": ["author": "xcode", "version": 1], "properties": ["provides-namespace": false]],
              to: output.appendingPathComponent("Contents.json"))

for heading in headings {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: heading, attributes: [.font: font]))
    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

    // Each glyph's outline, placed where the line sets it, with the baseline above the descent
    let outline = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for index in 0..<count {
            guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else { continue }
            outline.addPath(glyph, transform: CGAffineTransform(translationX: positions[index].x, y: positions[index].y + descent))
        }
    }

    let name = "Heading \(heading)"
    let imageset = output.appendingPathComponent("\(name).imageset")
    try FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)
    let pdf = imageset.appendingPathComponent("\(heading).pdf")
    var box = CGRect(x: 0, y: 0, width: ceil(width), height: ceil(ascent + descent))
    guard let context = CGContext(pdf as CFURL, mediaBox: &box, nil) else { exit(1) }
    context.beginPDFPage(nil)
    context.addPath(outline)
    context.setFillColor(.black)
    context.fillPath()
    context.endPDFPage()
    context.closePDF()

    try writeJSON([
        "images": [["filename": "\(heading).pdf", "idiom": "universal"]],
        "info": ["author": "xcode", "version": 1],
        "properties": ["preserves-vector-representation": true, "template-rendering-intent": "template"],
    ], to: imageset.appendingPathComponent("Contents.json"))
    print("Drew \(name)")
}
