import Foundation

enum TokenmonAppResourceLocator {
    static func resourceURL(relativePath: String) -> URL? {
        let fm = FileManager.default

        if let bundled = TokenmonAppResourceBundle.current.resourceURL?.appendingPathComponent(relativePath),
           fm.fileExists(atPath: bundled.path)
        {
            return bundled
        }

        if let flat = Bundle.main.resourceURL?.appendingPathComponent(relativePath),
           fm.fileExists(atPath: flat.path)
        {
            return flat
        }

        return nil
    }
}

@MainActor
enum TokenmonAppAssetResolver {
    private static var resolvedURLCache: [String: URL] = [:]
    private static var missingURLCache = Set<String>()
    private static var sourceSearchRoots: [URL]?

    static func url(
        sourceRelativePath: String,
        bundledRelativePath: String? = nil
    ) -> URL? {
        let cacheKey = "\(sourceRelativePath)|\(bundledRelativePath ?? "")"
        if let cached = resolvedURLCache[cacheKey] {
            return cached
        }
        if missingURLCache.contains(cacheKey) {
            return nil
        }

        let fm = FileManager.default
        for root in sourceRoots() {
            let candidate = root.appendingPathComponent(sourceRelativePath)
            if fm.fileExists(atPath: candidate.path) {
                resolvedURLCache[cacheKey] = candidate
                return candidate
            }
        }

        if let bundledRelativePath,
           let bundled = TokenmonAppResourceLocator.resourceURL(relativePath: bundledRelativePath)
        {
            resolvedURLCache[cacheKey] = bundled
            return bundled
        }

        missingURLCache.insert(cacheKey)
        return nil
    }

    private static func sourceRoots() -> [URL] {
        if let sourceSearchRoots {
            return sourceSearchRoots
        }

        let fm = FileManager.default
        var roots = [URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)]
        if let executableURL = Bundle.main.executableURL {
            var candidate = executableURL.deletingLastPathComponent()
            for _ in 0..<8 {
                roots.append(candidate)
                candidate.deleteLastPathComponent()
            }
        }

        var seen = Set<String>()
        let uniqueRoots = roots.filter { root in
            seen.insert(root.path).inserted
        }
        sourceSearchRoots = uniqueRoots
        return uniqueRoots
    }
}
