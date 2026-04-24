import AppKit
import Foundation
import SwiftUI

@MainActor
enum TokenmonRaidArtLoader {
    private static var cache: [String: NSImage] = [:]

    static func image(artKey: String) -> NSImage? {
        if let cached = cache[artKey] {
            return cached
        }

        let candidatePaths = [
            "raid/\(artKey).png",
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

struct TokenmonRaidArtImage: View {
    let artKey: String
    var saturation: Double = 1.0
    var brightness: Double = 0.0

    var body: some View {
        if let image = TokenmonRaidArtLoader.image(artKey: artKey) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .saturation(saturation)
                .brightness(brightness)
        }
    }
}
