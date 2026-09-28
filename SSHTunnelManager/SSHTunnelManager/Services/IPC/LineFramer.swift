import Foundation

enum LineFramerError: Error {
    case frameTooLarge
}

struct LineFramer {
    static let maxFrameSize = 65536 // 64 KiB limit, enforced per line
    private var buffer = Data()

    /// Accumulates bytes and returns every complete line received. Each line
    /// slice (between newlines) is checked against maxFrameSize individually,
    /// so a newline-embedded payload cannot grow the buffer without bound.
    mutating func append(_ data: Data) throws -> [String] {
        buffer.append(data)

        var lines: [String] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
            if lineData.count > Self.maxFrameSize {
                buffer.removeAll()
                throw LineFramerError.frameTooLarge
            }
            buffer.removeSubrange(buffer.startIndex...newlineIndex)

            var cleaned = lineData
            if cleaned.last == 0x0D { // carriage return
                cleaned.removeLast()
            }
            if let str = String(data: cleaned, encoding: .utf8) {
                lines.append(str)
            }
        }

        // No newline yet: the unterminated tail itself must stay within the limit.
        if buffer.count > Self.maxFrameSize {
            buffer.removeAll()
            throw LineFramerError.frameTooLarge
        }

        return lines
    }
}
