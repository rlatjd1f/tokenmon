import AppKit
import Foundation
import SwiftUI

enum TokenmonSpeciesSpriteVariant: String, CaseIterable {
    case portrait64 = "portrait_64.png"
    case portrait32 = "portrait_32.png"
}

@MainActor
enum TokenmonSpeciesSpriteLoader {
    private static var cache: [String: NSImage] = [:]
    private static let approvedPortraitPrefix = "approved-portrait:"

    static func image(assetKey: String, variant: TokenmonSpeciesSpriteVariant) -> NSImage? {
        if variant.isPortraitVariant, let approvedPortrait = approvedPortraitImage(assetKey: assetKey) {
            return approvedPortrait
        }

        let cacheKey = "\(assetKey):\(variant.rawValue)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = spriteURL(assetKey: assetKey, variant: variant),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        cache[cacheKey] = image
        return image
    }

    private static func spriteURL(assetKey: String, variant: TokenmonSpeciesSpriteVariant) -> URL? {
        TokenmonAppAssetResolver.url(
            sourceRelativePath: "assets/sprites/species/\(assetKey)/\(variant.rawValue)",
            bundledRelativePath: "sprites/species/\(assetKey)/\(variant.rawValue)"
        )
    }

    static func image(assetKey: String, variants: [TokenmonSpeciesSpriteVariant]) -> NSImage? {
        if variants.contains(where: \.isPortraitVariant),
           let approvedPortrait = approvedPortraitImage(assetKey: assetKey)
        {
            return approvedPortrait
        }

        for variant in variants {
            if let image = image(assetKey: assetKey, variant: variant) {
                return image
            }
        }
        return nil
    }

    static func notificationAttachmentURL(assetKey: String) -> URL? {
        approvedPortraitURL(assetKey: assetKey)
            ?? spriteURL(
                assetKey: assetKey,
                variants: [.portrait64, .portrait32]
            )
    }

    static func approvedPortraitImage(assetKey: String) -> NSImage? {
        let cacheKey = "\(approvedPortraitPrefix)\(assetKey)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = approvedPortraitURL(assetKey: assetKey),
              let sourceImage = NSImage(contentsOf: url) else {
            return nil
        }

        let image = trimmedImage(sourceImage) ?? sourceImage
        cache[cacheKey] = image
        return image
    }

    static func hasImage(assetKey: String, variant: TokenmonSpeciesSpriteVariant) -> Bool {
        spriteURL(assetKey: assetKey, variant: variant) != nil
    }

    static func hasImage(assetKey: String, variants: [TokenmonSpeciesSpriteVariant]) -> Bool {
        variants.contains { hasImage(assetKey: assetKey, variant: $0) }
    }

    private static func spriteURL(assetKey: String, variants: [TokenmonSpeciesSpriteVariant]) -> URL? {
        for variant in variants {
            if let url = spriteURL(assetKey: assetKey, variant: variant) {
                return url
            }
        }
        return nil
    }

    private static func approvedPortraitURL(assetKey: String) -> URL? {
        TokenmonAppAssetResolver.url(
            sourceRelativePath: "art/source/species/approved-portraits/\(assetKey).png"
        )
    }

    private static func trimmedImage(_ image: NSImage) -> NSImage? {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let trimmedRect = nonTransparentBounds(in: bitmap)
        else {
            return nil
        }

        guard
            let cgImage = bitmap.cgImage,
            let croppedCGImage = cgImage.cropping(to: trimmedRect)
        else {
            return nil
        }

        let cropped = NSBitmapImageRep(cgImage: croppedCGImage)
        let result = NSImage(size: NSSize(width: cropped.pixelsWide, height: cropped.pixelsHigh))
        result.addRepresentation(cropped)
        return result
    }

    private static func nonTransparentBounds(in bitmap: NSBitmapImageRep) -> NSRect? {
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.01 else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        return NSRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }
}

private extension TokenmonSpeciesSpriteVariant {
    var isPortraitVariant: Bool {
        true
    }
}

struct TokenmonSpeciesSpriteImage: View {
    let assetKey: String
    let variants: [TokenmonSpeciesSpriteVariant]
    let revealStage: TokenmonSpeciesArtRevealStage

    init(assetKey: String, variant: TokenmonSpeciesSpriteVariant, revealStage: TokenmonSpeciesArtRevealStage = .revealed) {
        self.assetKey = assetKey
        self.variants = [variant]
        self.revealStage = revealStage
    }

    init(assetKey: String, variants: [TokenmonSpeciesSpriteVariant], revealStage: TokenmonSpeciesArtRevealStage = .revealed) {
        self.assetKey = assetKey
        self.variants = variants
        self.revealStage = revealStage
    }

    var body: some View {
        if let image = TokenmonSpeciesSpriteLoader.image(assetKey: assetKey, variants: variants) {
            if revealStage == .silhouette {
                Color.black.opacity(0.82)
                    .mask(
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                    )
            } else if revealStage == .revealed {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
            } else {
                TokenmonSpeciesFragmentReveal(
                    image: image,
                    revealStage: revealStage
                )
            }
        }
    }
}

private struct TokenmonSpeciesFragmentReveal: View {
    let image: NSImage
    let revealStage: TokenmonSpeciesArtRevealStage

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.black.opacity(silhouetteOpacity)
                    .mask(
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                    )

                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .saturation(saturation)
                    .brightness(brightness)
                    .mask(
                        TokenmonSpeciesRevealMask(
                            revealStage: revealStage,
                            size: size
                        )
                    )

                TokenmonSpeciesRevealGrid(
                    revealStage: revealStage,
                    size: size
                )
                .mask(
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                )
                .blendMode(.plusLighter)
                .opacity(gridOpacity)
            }
        }
    }

    private var saturation: Double {
        switch revealStage {
        case .heavyBlur:
            return 0.52
        case .mediumBlur:
            return 0.68
        case .lightBlur:
            return 0.82
        case .silhouette, .revealed:
            return 1
        }
    }

    private var brightness: Double {
        switch revealStage {
        case .heavyBlur:
            return -0.08
        case .mediumBlur:
            return -0.05
        case .lightBlur:
            return -0.02
        case .silhouette, .revealed:
            return 0
        }
    }

    private var silhouetteOpacity: Double {
        switch revealStage {
        case .heavyBlur:
            return 0.48
        case .mediumBlur:
            return 0.38
        case .lightBlur:
            return 0.28
        case .silhouette, .revealed:
            return 0
        }
    }

    private var gridOpacity: Double {
        switch revealStage {
        case .heavyBlur:
            return 0.26
        case .mediumBlur:
            return 0.18
        case .lightBlur:
            return 0.10
        case .silhouette, .revealed:
            return 0
        }
    }
}

private struct TokenmonSpeciesRevealMask: View {
    let revealStage: TokenmonSpeciesArtRevealStage
    let size: CGSize

    private static let heavyCells: Set<Int> = [1, 4, 8, 13, 17, 22, 28, 31]
    private static let mediumCells: Set<Int> = heavyCells.union([0, 3, 9, 12, 15, 20, 24, 29])
    private static let lightCells: Set<Int> = mediumCells.union([2, 5, 10, 14, 18, 21, 26, 30, 34])

    var body: some View {
        let columns = 6
        let rows = 6
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)

        ZStack(alignment: .topLeading) {
            ForEach(Array(activeCells), id: \.self) { index in
                let column = index % columns
                let row = index / columns

                RoundedRectangle(cornerRadius: min(cellWidth, cellHeight) * 0.18, style: .continuous)
                    .frame(width: cellWidth * 0.92, height: cellHeight * 0.92)
                    .offset(
                        x: CGFloat(column) * cellWidth + cellWidth * 0.04,
                        y: CGFloat(row) * cellHeight + cellHeight * 0.04
                    )
            }
        }
    }

    private var activeCells: Set<Int> {
        switch revealStage {
        case .heavyBlur:
            return Self.heavyCells
        case .mediumBlur:
            return Self.mediumCells
        case .lightBlur:
            return Self.lightCells
        case .silhouette, .revealed:
            return []
        }
    }
}

private struct TokenmonSpeciesRevealGrid: View {
    let revealStage: TokenmonSpeciesArtRevealStage
    let size: CGSize

    var body: some View {
        let columns = 6
        let rows = 6
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)

        ZStack(alignment: .topLeading) {
            ForEach(1..<columns, id: \.self) { column in
                Rectangle()
                    .fill(Color.white.opacity(lineOpacity))
                    .frame(width: 1, height: size.height)
                    .offset(x: CGFloat(column) * cellWidth, y: 0)
            }

            ForEach(1..<rows, id: \.self) { row in
                Rectangle()
                    .fill(Color.white.opacity(lineOpacity))
                    .frame(width: size.width, height: 1)
                    .offset(x: 0, y: CGFloat(row) * cellHeight)
            }
        }
    }

    private var lineOpacity: Double {
        switch revealStage {
        case .heavyBlur:
            return 0.24
        case .mediumBlur:
            return 0.18
        case .lightBlur:
            return 0.10
        case .silhouette, .revealed:
            return 0
        }
    }
}
