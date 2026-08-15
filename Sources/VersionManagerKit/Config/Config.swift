package struct Config: Decodable, Sendable, Equatable {
    package var version: VersionFormat
    package var sourceOfTruth: String?
    package var files: [FileRule]
    package var renames: [RenameRule]?
    package var hooks: Hooks?

    package enum CodingKeys: String, CodingKey {
        case version
        case sourceOfTruth = "source_of_truth"
        case files
        case renames
        case hooks
    }

    package struct VersionFormat: Decodable, Sendable, Equatable {
        package var format: Format
        package var pattern: String?
        package var strict: Bool?

        package enum Format: String, Decodable, Sendable, Equatable {
            case semver
            case pattern
        }
    }

    package struct FileRule: Decodable, Sendable, Equatable {
        package var id: String
        package var path: String
        package var pattern: String
        package var occurrences: Occurrences = .all

        package enum CodingKeys: String, CodingKey {
            case id, path, pattern, occurrences
        }

        package init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            path = try container.decode(String.self, forKey: .path)
            pattern = try container.decode(String.self, forKey: .pattern)
            occurrences = try container.decodeIfPresent(Occurrences.self, forKey: .occurrences) ?? .all
        }
    }

    package enum Occurrences: Decodable, Sendable, Equatable {
        case all
        case exactly(Int)

        package init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intValue = try? container.decode(Int.self) {
                self = .exactly(intValue)
                return
            }
            if let stringValue = try? container.decode(String.self), stringValue == "all" {
                self = .all
                return
            }
            throw DecodingError.typeMismatch(
                Occurrences.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected \"all\" or an integer for occurrences"
                )
            )
        }
    }

    package struct RenameRule: Decodable, Sendable, Equatable {
        package var id: String
        package var directory: String
        package var format: String
        package var transform: Transform?

        package struct Transform: Decodable, Sendable, Equatable {
            package var run: String
        }
    }

    package struct Hooks: Decodable, Sendable, Equatable {
        package var pre: [Hook]?
        package var post: [Hook]?

        package struct Hook: Decodable, Sendable, Equatable {
            package var name: String
            package var run: String
        }
    }
}
