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
    case campMat64 = "camp_mat_64.png"
    case campPropPrimary32 = "camp_prop_primary_32.png"
    case campPropSecondary32 = "camp_prop_secondary_32.png"
    case campProp32 = "camp_prop_32.png"
    case careFX16 = "care_fx_16.png"
    case trainFX16 = "train_fx_16.png"
    case resonanceOrb16 = "resonance_orb_16.png"
    case trainingSuccess16 = "training_success_16.png"
    case trainingFail16 = "training_fail_16.png"

    var fallbackVariant: NowCampEffectSpriteVariant? {
        switch self {
        case .campPropPrimary32, .campPropSecondary32:
            return .campProp32
        case .campMat64, .campProp32, .careFX16, .trainFX16, .resonanceOrb16, .trainingSuccess16, .trainingFail16:
            return nil
        }
    }
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
              let image = NSImage(contentsOf: url) else {
            if let fallbackVariant = variant.fallbackVariant {
                return self.image(scope: scope, variant: fallbackVariant)
            }
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
