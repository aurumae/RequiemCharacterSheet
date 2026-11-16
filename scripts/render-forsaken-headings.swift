// render-forsaken-headings.swift
//
// Draws Forsaken's section headings in Flat Earth Scribe as vector pictures: PDFs for the iOS asset catalog, and
// Android vector drawables with a manifest in shared/forsaken-headings/ for the Android app.
//
// Flat Earth Scribe (Nate Piekos, Blambot) is licensed for desktop use only, so it must never ship in either app.
// This draws each heading's letters as filled outlines, not text, so the PDFs hold no font. Run it on a Mac with the
// font installed whenever a Forsaken section is added or renamed:
//
//     swift scripts/render-forsaken-headings.swift
//
// The apps tint the pictures Werewolf Rust and scale them with the text size; see `SectionHeading` on iOS. Android
// needs no font and no conversion: it uses the drawables as they are.

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
let androidOutput = URL(fileURLWithPath: "shared/forsaken-headings")

/// The outline as path data, for an Android vector drawable: y runs down, so it's flipped within `height`.
func pathData(_ path: CGPath, height: CGFloat) -> String {
    func point(_ p: CGPoint) -> String {
        String(format: "%.2f,%.2f", p.x, height - p.y)
    }
    var commands: [String] = []
    path.applyWithBlock { element in
        let points = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint: commands.append("M" + point(points[0]))
        case .addLineToPoint: commands.append("L" + point(points[0]))
        case .addQuadCurveToPoint: commands.append("Q" + point(points[0]) + " " + point(points[1]))
        case .addCurveToPoint: commands.append("C" + point(points[0]) + " " + point(points[1]) + " " + point(points[2]))
        case .closeSubpath: commands.append("Z")
        @unknown default: break
        }
    }
    return commands.joined()
}

/// e.g. "heading_kuruth_triggers", a valid Android resource name.
func resourceName(_ heading: String) -> String {
    "heading_" + heading.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
}

var manifest: [[String: Any]] = []

guard let font = NSFont(name: "FlatEarthScribe", size: pointSize) else {
    print("Flat Earth Scribe isn't installed on this Mac.")
    exit(1)
}

func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: androidOutput, withIntermediateDirectories: true)
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

    // The same outline for Android, in dp at the drawn size, filled black for the app to tint
    let resource = resourceName(heading)
    let drawable = """
    <?xml version="1.0" encoding="utf-8"?>
    <!-- \(heading), drawn from Flat Earth Scribe outlines by scripts/render-forsaken-headings.swift. Don't edit. -->
    <vector xmlns:android="http://schemas.android.com/apk/res/android"
        android:width="\(Int(box.width))dp"
        android:height="\(Int(box.height))dp"
        android:viewportWidth="\(Int(box.width))"
        android:viewportHeight="\(Int(box.height))">
        <path
            android:fillColor="#FF000000"
            android:pathData="\(pathData(outline, height: box.height))" />
    </vector>

    """
    try drawable.write(to: androidOutput.appendingPathComponent("\(resource).xml"), atomically: true, encoding: .utf8)
    manifest.append(["heading": heading, "drawable": resource, "width": Int(box.width), "height": Int(box.height)])
    print("Drew \(name)")
}

// The headings, their drawables and sizes, so the Android app (and its tests) can check none is missing
try writeJSON(["pointSize": pointSize, "headings": manifest], to: androidOutput.appendingPathComponent("headings.json"))
