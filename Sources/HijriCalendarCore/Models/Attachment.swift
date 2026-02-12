import Foundation

public enum AttachmentType: String, Codable {
    case photo
    case file
    case link
}

public struct Attachment: Identifiable, Hashable, Codable {
    public let id: UUID
    public let type: AttachmentType
    public let path: String?
    public let url: String?
    public let displayName: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        type: AttachmentType,
        path: String? = nil,
        url: String? = nil,
        displayName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.path = path
        self.url = url
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
