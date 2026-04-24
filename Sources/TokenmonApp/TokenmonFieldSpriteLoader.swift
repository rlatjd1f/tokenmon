import AppKit
import Foundation
import SwiftUI

enum TokenmonFieldSpriteVariant: String {
    case grasslandTuft = "grassland_tuft.png"
    case skyCloud = "sky_cloud.png"
    case coastWave = "coast_wave.png"
    case iceSnowflake = "ice_snowflake.png"
}

enum TokenmonPopoverBackgroundSlot: String, CaseIterable {
    case morning
    case day
    case evening
    case night

    static func resolve(hour: Int) -> TokenmonPopoverBackgroundSlot {
        let normalizedHour = ((hour % 24) + 24) % 24

        switch normalizedHour {
        case 5..<11:
            return .morning
        case 11..<17:
            return .day
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    static func resolve(
        at date: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> TokenmonPopoverBackgroundSlot {
        resolve(hour: calendar.component(.hour, from: date))
    }
}

@MainActor
enum TokenmonFieldSpriteLoader {
    private static var cache: [String: NSImage] = [:]
    private static let popoverBackgroundPrefix = "popover-background:"

    static func image(field: TokenmonSceneFieldKind, variant: TokenmonFieldSpriteVariant) -> NSImage? {
        let cacheKey = "\(field.rawValue):\(variant.rawValue)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = spriteURL(field: field, variant: variant),
              let sourceImage = NSImage(contentsOf: url) else {
            return nil
        }

        let image = trimmedImage(sourceImage) ?? sourceImage
        cache[cacheKey] = image
        return image
    }

    static func popoverBackgroundImage(
        field: TokenmonSceneFieldKind,
        at date: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> NSImage? {
        guard let relativePath = popoverBackgroundRelativePath(field: field, at: date, calendar: calendar) else {
            return nil
        }

        let cacheKey = "\(popoverBackgroundPrefix)\(relativePath)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = resourceURL(relative: "assets/\(relativePath)", bundledRelative: relativePath),
              let sourceImage = NSImage(contentsOf: url) else {
            return nil
        }

        let image = trimmedImage(sourceImage) ?? sourceImage
        cache[cacheKey] = image
        return image
    }

    static func popoverBackgroundRelativePath(
        field: TokenmonSceneFieldKind,
        at date: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> String? {
        switch field {
        case .coast, .grassland, .ice, .sky:
            let slot = TokenmonPopoverBackgroundSlot.resolve(at: date, calendar: calendar)
            return "backgrounds/popover/\(field.rawValue)/\(slot.rawValue).png"
        default:
            return nil
        }
    }

    private static func spriteURL(field: TokenmonSceneFieldKind, variant: TokenmonFieldSpriteVariant) -> URL? {
        let relative = "assets/sprites/fields/\(field.rawValue)/\(variant.rawValue)"
        return resourceURL(
            relative: relative,
            bundledRelative: "sprites/fields/\(field.rawValue)/\(variant.rawValue)"
        )
    }

    private static func resourceURL(relative: String, bundledRelative: String) -> URL? {
        let fm = FileManager.default

        let cwdURL = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(relative)
        if fm.fileExists(atPath: cwdURL.path) {
            return cwdURL
        }

        if let executableURL = Bundle.main.executableURL {
            var candidate = executableURL.deletingLastPathComponent()
            for _ in 0..<8 {
                let url = candidate.appendingPathComponent(relative)
                if fm.fileExists(atPath: url.path) {
                    return url
                }
                candidate.deleteLastPathComponent()
            }
        }

        if let bundled = TokenmonAppResourceLocator.resourceURL(relativePath: bundledRelative) {
            return bundled
        }

        return nil
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

struct TokenmonFieldSpriteImage: View {
    let field: TokenmonSceneFieldKind
    let variant: TokenmonFieldSpriteVariant

    var body: some View {
        if let image = TokenmonFieldSpriteLoader.image(field: field, variant: variant) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
        }
    }
}
