import AppKit
import Foundation
import SwiftUI
import TokenmonDomain

enum NowCampEffectSpriteScope: Hashable {
    case common
    case field(FieldType)

    var directoryName: String {
        switch self {
        case .common:
            return "common"
        case .field(let field):
            return field.rawValue
        }
    }
}

enum NowCampEffectSpriteVariant: String, CaseIterable {
    case campProp32 = "camp_prop_32.png"
    case careFX16 = "care_fx_16.png"
    case trainFX16 = "train_fx_16.png"
    case resonanceOrb16 = "resonance_orb_16.png"
    case trainingSuccess16 = "training_success_16.png"
    case trainingFail16 = "training_fail_16.png"
}

@MainActor
enum NowCampEffectSpriteLoader {
    private static var cache: [String: NSImage] = [:]

    static func image(scope: NowCampEffectSpriteScope, variant: NowCampEffectSpriteVariant) -> NSImage? {
        let cacheKey = "\(scope.directoryName)/\(variant.rawValue)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = spriteURL(scope: scope, variant: variant),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        cache[cacheKey] = image
        return image
    }

    private static func spriteURL(scope: NowCampEffectSpriteScope, variant: NowCampEffectSpriteVariant) -> URL? {
        let relative = "effects/now-camp/runtime/\(scope.directoryName)/\(variant.rawValue)"
        return TokenmonAppAssetResolver.url(
            sourceRelativePath: "assets/sprites/\(relative)",
            bundledRelativePath: "sprites/\(relative)"
        )
    }
}

struct NowCampEffectSpriteImage: View {
    let scope: NowCampEffectSpriteScope
    let variant: NowCampEffectSpriteVariant

    var body: some View {
        if let image = NowCampEffectSpriteLoader.image(scope: scope, variant: variant) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
        }
    }
}
