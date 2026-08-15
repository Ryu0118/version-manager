import Foundation
import RegexBuilder

package struct SemanticVersion: Equatable, Comparable, CustomStringConvertible, Sendable {
    package let major: Int
    package let minor: Int
    package let patch: Int
    package let preRelease: [PreReleaseIdentifier]
    package let buildMetadata: String?

    package enum PreReleaseIdentifier: Equatable, Sendable {
        case numeric(Int)
        case alphanumeric(String)
    }

    package init(
        major: Int,
        minor: Int,
        patch: Int,
        preRelease: [PreReleaseIdentifier] = [],
        buildMetadata: String? = nil
    ) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preRelease = preRelease
        self.buildMetadata = buildMetadata
    }

    package var description: String {
        var result = "\(major).\(minor).\(patch)"
        if !preRelease.isEmpty {
            let identifiers = preRelease.map { identifier -> String in
                switch identifier {
                case let .numeric(value): String(value)
                case let .alphanumeric(value): value
                }
            }
            result += "-" + identifiers.joined(separator: ".")
        }
        if let buildMetadata {
            result += "+" + buildMetadata
        }
        return result
    }

    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.major == rhs.major
            && lhs.minor == rhs.minor
            && lhs.patch == rhs.patch
            && lhs.preRelease == rhs.preRelease
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }
        return preReleaseIsLess(lhs.preRelease, rhs.preRelease)
    }

    private static func preReleaseIsLess(_ lhs: [PreReleaseIdentifier], _ rhs: [PreReleaseIdentifier]) -> Bool {
        if lhs.isEmpty {
            return false // release > pre-release (or both are releases)
        }
        if rhs.isEmpty {
            return true // pre-release < release
        }

        for (left, right) in zip(lhs, rhs) where left != right {
            return identifierIsLess(left, right)
        }
        return lhs.count < rhs.count
    }

    private static func identifierIsLess(_ lhs: PreReleaseIdentifier, _ rhs: PreReleaseIdentifier) -> Bool {
        switch (lhs, rhs) {
        case let (.numeric(lhsValue), .numeric(rhsValue)):
            lhsValue < rhsValue
        case (.numeric, .alphanumeric):
            true // numeric identifiers always have lower precedence
        case (.alphanumeric, .numeric):
            false
        case let (.alphanumeric(lhsValue), .alphanumeric(rhsValue)):
            lhsValue < rhsValue
        }
    }
}

package enum SemanticVersionParseError: Error, LocalizedError, Equatable {
    case invalidFormat(input: String)
    case componentOverflow(input: String, component: String)

    package var errorDescription: String? {
        switch self {
        case let .invalidFormat(input):
            "\"\(input)\" is not a valid SemVer 2.0.0 version string"
        case let .componentOverflow(input, component):
            "\"\(input)\" has an out-of-range \(component) component"
        }
    }
}

private var numericIdentifier: some RegexComponent<Substring> {
    Regex {
        ChoiceOf {
            "0"
            Regex {
                CharacterClass("1" ... "9")
                ZeroOrMore(.digit)
            }
        }
    }
}

private var alphanumericIdentifier: some RegexComponent<Substring> {
    OneOrMore(CharacterClass(.digit, .anyOf("-"), "a" ... "z", "A" ... "Z"))
}

private var preReleaseIdentifier: some RegexComponent<Substring> {
    ChoiceOf {
        alphanumericIdentifier
        numericIdentifier
    }
}

private var buildIdentifier: some RegexComponent<Substring> {
    OneOrMore(CharacterClass(.digit, "a" ... "z", "A" ... "Z", .anyOf("-")))
}

private var preReleaseGroup: some RegexComponent<Substring> {
    Regex {
        preReleaseIdentifier
        ZeroOrMore {
            "."
            preReleaseIdentifier
        }
    }
}

private var buildGroup: some RegexComponent<Substring> {
    Regex {
        buildIdentifier
        ZeroOrMore {
            "."
            buildIdentifier
        }
    }
}

// swiftlint:disable:next large_tuple
private var semanticVersionPattern: Regex<(Substring, Substring, Substring, Substring, Substring?, Substring?)> {
    Regex {
        Anchor.startOfSubject
        Capture { numericIdentifier } // major
        "."
        Capture { numericIdentifier } // minor
        "."
        Capture { numericIdentifier } // patch
        Optionally {
            "-"
            Capture { preReleaseGroup } // preRelease
        }
        Optionally {
            "+"
            Capture { buildGroup } // buildMetadata
        }
        Anchor.endOfSubject
    }
}

private func parsePreReleaseIdentifiers(_ substring: Substring?) -> [SemanticVersion.PreReleaseIdentifier] {
    guard let substring else {
        return []
    }
    return String(substring).split(separator: ".").map { part in
        if let intValue = Int(part), String(intValue) == part {
            .numeric(intValue)
        } else {
            .alphanumeric(String(part))
        }
    }
}

package extension SemanticVersion {
    init(parsing input: String) throws(SemanticVersionParseError) {
        guard let match = input.wholeMatch(of: semanticVersionPattern) else {
            throw SemanticVersionParseError.invalidFormat(input: input)
        }

        guard
            let majorInt = Int(match.output.1),
            let minorInt = Int(match.output.2),
            let patchInt = Int(match.output.3)
        else {
            throw SemanticVersionParseError.componentOverflow(input: input, component: "major/minor/patch")
        }

        self.init(
            major: majorInt,
            minor: minorInt,
            patch: patchInt,
            preRelease: parsePreReleaseIdentifiers(match.output.4),
            buildMetadata: match.output.5.map(String.init)
        )
    }
}
