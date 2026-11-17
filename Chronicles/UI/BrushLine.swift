//
//  BrushLine.swift
//  Chronicles
//
//  The Werewolf sheet's section divider, drawn rather than copied from its artwork.
//

import SwiftUI

/// A rough brush stroke, solid at one end and breaking into ragged dashes and flecks towards the other, as on the
/// Werewolf sheet. Drawn from a seed, so the same line looks the same every time.
struct BrushLine: View {
    @Environment(\.theme) private var theme
    let seed: String
    /// The end that's solid, beside the heading.
    let solidEnd: HorizontalEdge

    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed)
            let length = size.width, middle = size.height / 2
            // Distance from the solid end
            var distance: CGFloat = 0
            while distance < length {
                let progress = distance / length
                let segment = lerp(80, 5, pow(progress, 0.7)) * random.next(in: 0.45...1.5)
                let thickness = lerp(4.6, 1.8, progress) * random.next(in: 0.75...1.2)
                let end = min(distance + segment, length)
                let drift = random.next(in: -0.9...0.9)
                var top: [CGPoint] = [], bottom: [CGPoint] = []
                let steps = max(2, Int((end - distance) / 2.5))
                for step in 0...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    let x = distance + t * (end - distance)
                    // Each dash tapers at both ends
                    let taper = pow(sin(.pi * min(max(t, 0.04), 0.96)), 0.35)
                    let y = middle + drift + sin(x / 41) * 0.9
                    top.append(CGPoint(x: x, y: y - thickness / 2 * taper * random.next(in: 0.55...1.3)))
                    bottom.append(CGPoint(x: x, y: y + thickness / 2 * taper * random.next(in: 0.55...1.3)))
                }
                var path = Path()
                path.move(to: placed(top[0], length))
                top.dropFirst().forEach { path.addLine(to: placed($0, length)) }
                bottom.reversed().forEach { path.addLine(to: placed($0, length)) }
                path.closeSubpath()
                context.fill(path, with: .color(theme.accent))
                // Flecks of ink where the stroke breaks up
                if progress > 0.35 && random.next(in: 0...1) < 0.35 {
                    let radius = random.next(in: 0.6...1.4)
                    let fleck = placed(CGPoint(x: end + random.next(in: 1...4), y: middle + random.next(in: -3.5...3.5)), length)
                    context.fill(Path(ellipseIn: CGRect(x: fleck.x - radius, y: fleck.y - radius, width: radius * 2, height: radius * 2)),
                                 with: .color(theme.accent))
                }
                distance = end + lerp(0.6, 9, progress) * random.next(in: 0.3...1.7)
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    /// Distances are measured from the solid end; this puts them on the right side.
    private func placed(_ point: CGPoint, _ length: CGFloat) -> CGPoint {
        solidEnd == .trailing ? CGPoint(x: length - point.x, y: point.y) : point
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

/// SplitMix64, seeded from a string with FNV-1a. Swift's own hashing changes from launch to launch, so it can't
/// seed a pattern that must stay the same.
private struct SeededRandom {
    private var state: UInt64

    init(_ seed: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        state = hash
    }

    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        let unit = CGFloat(z ^ (z >> 31)) / CGFloat(UInt64.max)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
