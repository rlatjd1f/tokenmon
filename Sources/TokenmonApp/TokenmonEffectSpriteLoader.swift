import AppKit
import Foundation
import SwiftUI

enum TokenmonEffectSpriteVariant: String, CaseIterable {
    case alert16 = "alert_16.png"
    case captureSnap16 = "capture_snap_16.png"
    case escapeDash16 = "escape_dash_16.png"
}

@MainActor
enum TokenmonEffectSpriteLoader {
    private static var cache: [String: NSImage] = [:]

    static func image(variant: TokenmonEffectSpriteVariant) -> NSImage? {
        let cacheKey = variant.rawValue
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = spriteURL(variant: variant),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        cache[cacheKey] = image
        return image
    }

    private static func spriteURL(variant: TokenmonEffectSpriteVariant) -> URL? {
        TokenmonAppAssetResolver.url(
            sourceRelativePath: "assets/sprites/effects/\(variant.rawValue)",
            bundledRelativePath: "sprites/effects/\(variant.rawValue)"
        )
    }
}

struct TokenmonEffectSpriteImage: View {
    let variant: TokenmonEffectSpriteVariant

    var body: some View {
        if let image = TokenmonEffectSpriteLoader.image(variant: variant) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
        }
    }
}
