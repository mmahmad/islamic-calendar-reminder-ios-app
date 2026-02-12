import Foundation

struct HTMLTextExtractor: TextExtracting {
    func extractText(from data: Data) -> String {
        let html = String(decoding: data, as: UTF8.self)
        guard !html.isEmpty else { return "" }

        var text = html
        text = stripBlock(tag: "script", in: text)
        text = stripBlock(tag: "style", in: text)
        text = replaceLineBreakTags(in: text)
        text = removeTags(in: text)
        text = decodeHTMLEntities(in: text)
        text = text.replacingOccurrences(of: "\r", with: "\n")

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.joined(separator: "\n")
    }

    private func stripBlock(tag: String, in text: String) -> String {
        let pattern = "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>"
        return replacingRegex(pattern: pattern, in: text, with: "\n")
    }

    private func replaceLineBreakTags(in text: String) -> String {
        let pattern = #"</?(p|div|br|tr|li|h[1-6])\b[^>]*>"#
        return replacingRegex(pattern: pattern, in: text, with: "\n")
    }

    private func removeTags(in text: String) -> String {
        replacingRegex(pattern: "<[^>]+>", in: text, with: " ")
    }

    private func replacingRegex(pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private func decodeHTMLEntities(in text: String) -> String {
        var output = text
        let namedEntities: [String: String] = [
            "nbsp": " ",
            "amp": "&",
            "quot": "\"",
            "apos": "'",
            "lt": "<",
            "gt": ">",
            "mdash": "-",
            "ndash": "-",
            "hellip": "...",
        ]

        output = replaceNamedEntities(in: output, mapping: namedEntities)

        output = decodeNumericEntities(in: output, pattern: "&#(\\d+);", radix: 10)
        output = decodeNumericEntities(in: output, pattern: "&#x([0-9A-Fa-f]+);", radix: 16)

        return output
    }

    private func replaceNamedEntities(in text: String, mapping: [String: String]) -> String {
        guard let regex = try? NSRegularExpression(pattern: "&([A-Za-z]+);", options: []) else {
            return text
        }
        let nsrange = NSRange(text.startIndex..., in: text)
        var output = text
        var offset = 0

        regex.enumerateMatches(in: text, options: [], range: nsrange) { match, _, _ in
            guard let match = match, match.numberOfRanges == 2,
                  let nameRange = Range(match.range(at: 1), in: text) else {
                return
            }
            let name = String(text[nameRange]).lowercased()
            guard let replacement = mapping[name] else { return }
            let matchRange = match.range(at: 0)
            let adjustedLocation = matchRange.location + offset
            let adjustedRange = NSRange(location: adjustedLocation, length: matchRange.length)
            if let swiftRange = Range(adjustedRange, in: output) {
                output.replaceSubrange(swiftRange, with: replacement)
                offset += replacement.utf16.count - matchRange.length
            }
        }

        return output
    }

    private func decodeNumericEntities(in text: String, pattern: String, radix: Int) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let nsrange = NSRange(text.startIndex..., in: text)
        var output = text
        var offset = 0

        regex.enumerateMatches(in: text, options: [], range: nsrange) { match, _, _ in
            guard let match = match, match.numberOfRanges == 2,
                  let codeRange = Range(match.range(at: 1), in: text) else {
                return
            }
            let codeString = String(text[codeRange])
            guard let codePoint = Int(codeString, radix: radix),
                  let scalar = UnicodeScalar(codePoint) else {
                return
            }
            let replacement = String(scalar)
            let matchRange = match.range(at: 0)
            let adjustedLocation = matchRange.location + offset
            let adjustedRange = NSRange(location: adjustedLocation, length: matchRange.length)
            if let swiftRange = Range(adjustedRange, in: output) {
                output.replaceSubrange(swiftRange, with: replacement)
                offset += replacement.utf16.count - matchRange.length
            }
        }

        return output
    }
}
