import Foundation

public struct ProviderInboxLine: Sendable {
    public let rawLine: String
    public let nextOffset: Int64
    public let newlineTerminated: Bool
}

public struct ProviderInboxReadResult: Sendable {
    public let lines: [ProviderInboxLine]
}

public enum ProviderInboxReader {
    private static let chunkSize = 64 * 1024

    public static func read(from path: String, startingAt offset: Int64 = 0) throws -> ProviderInboxReadResult {
        var lines: [ProviderInboxLine] = []
        try readLines(from: path, startingAt: offset) { line in
            lines.append(line)
        }
        return ProviderInboxReadResult(lines: lines)
    }

    public static func readLines(
        from path: String,
        startingAt offset: Int64 = 0,
        _ handleLine: (ProviderInboxLine) throws -> Void
    ) throws {
        let fileURL = URL(fileURLWithPath: path)
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let startingOffset = max(0, offset)
        guard startingOffset < Int64(fileSize) else {
            return
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? handle.close()
        }

        try handle.seek(toOffset: UInt64(startingOffset))

        var buffer = Data()
        var cursor = startingOffset

        while let chunk = try handle.read(upToCount: chunkSize), chunk.isEmpty == false {
            buffer.append(chunk)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newlineIndex]
                let line = String(decoding: lineData, as: UTF8.self)
                let nextOffset = cursor + Int64(newlineIndex) + 1
                try handleLine(ProviderInboxLine(rawLine: line, nextOffset: nextOffset, newlineTerminated: true))
                buffer.removeSubrange(buffer.startIndex...newlineIndex)
                cursor = nextOffset
            }
        }

        if buffer.isEmpty == false {
            try handleLine(
                ProviderInboxLine(
                    rawLine: String(decoding: buffer, as: UTF8.self),
                    nextOffset: cursor + Int64(buffer.count),
                    newlineTerminated: false
                )
            )
        }
    }
}
