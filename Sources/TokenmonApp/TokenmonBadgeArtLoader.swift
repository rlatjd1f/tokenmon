import AppKit
import SwiftUI

@MainActor
enum TokenmonBadgeArtLoader {
    private static var cache: [String: NSImage] = [:]

    static func image(artKey: String) -> NSImage? {
        if let cached = cache[artKey] {
            return cached
        }

        let candidatePaths = [
            "badges/\(artKey).png",
            "\(artKey).png",
        ]

        for relativePath in candidatePaths {
            if let url = TokenmonAppResourceLocator.resourceURL(relativePath: relativePath),
               let image = NSImage(contentsOf: url) {
                cache[artKey] = image
                return image
            }
        }
        return nil
    }
}

struct TokenmonBadgeArtImage: View {
    let artKey: String
    let isUnlocked: Bool

    var body: some View {
        Group {
            if let image = TokenmonBadgeArtLoader.image(artKey: artKey) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .saturation(isUnlocked ? 1 : 0)
                    .brightness(isUnlocked ? 0 : -0.20)
                    .opacity(isUnlocked ? 1 : 0.42)
            } else {
                fallback
            }
        }
        .overlay {
            if !isUnlocked {
                Circle()
                    .fill(Color.black.opacity(0.20))
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.78))
                    .padding(10)
                    .background(Circle().fill(Color(nsColor: .controlBackgroundColor).opacity(0.86)))
            }
        }
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(isUnlocked ? 0.30 : 0.08),
                            Color.secondary.opacity(0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .stroke(Color.accentColor.opacity(isUnlocked ? 0.34 : 0.12), lineWidth: 2)
            Image(systemName: "rosette")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(isUnlocked ? Color.accentColor : Color.secondary.opacity(0.58))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
