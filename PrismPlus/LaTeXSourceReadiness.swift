import Foundation

enum LaTeXSourceReadiness {
    static func isReady(_ source: String) -> Bool {
        var stack: [Character] = []
        var isEscaped = false
        var isComment = false
        let closingForOpening: [Character: Character] = ["{": "}", "[": "]", "(": ")"]

        for character in source {
            if character == "\n" {
                isComment = false
                isEscaped = false
                continue
            }
            if isComment { continue }
            if character == "%" && !isEscaped {
                isComment = true
                continue
            }
            if character == "\\" {
                isEscaped.toggle()
                continue
            }
            if isEscaped {
                isEscaped = false
                continue
            }

            if closingForOpening[character] != nil {
                stack.append(character)
            } else if let opening = stack.last, closingForOpening[opening] == character {
                stack.removeLast()
            } else if closingForOpening.values.contains(character) {
                return false
            }
        }

        return stack.isEmpty
    }
}
