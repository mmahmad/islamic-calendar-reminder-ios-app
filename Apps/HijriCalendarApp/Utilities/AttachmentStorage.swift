import Foundation
import HijriCalendarCore

enum AttachmentStorage {
    private static let attachmentsDirectoryName = "Attachments"

    static func savePhotoData(_ data: Data) -> Attachment? {
        let directory = attachmentsDirectory()
        let filename = "photo-\(UUID().uuidString).dat"
        let url = directory.appendingPathComponent(filename)
        let relativePath = storedPath(forFilename: filename)

        do {
            try data.write(to: url, options: [.atomic])
            return Attachment(
                type: .photo,
                path: relativePath,
                displayName: "Photo"
            )
        } catch {
            return nil
        }
    }

    static func importFile(from url: URL) -> Attachment? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let directory = attachmentsDirectory()
        let filename = url.lastPathComponent
        let targetName = "\(UUID().uuidString)-\(filename)"
        let targetURL = directory.appendingPathComponent(targetName)
        let relativePath = storedPath(forFilename: targetName)

        do {
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.copyItem(at: url, to: targetURL)
            return Attachment(
                type: .file,
                path: relativePath,
                displayName: filename
            )
        } catch {
            return nil
        }
    }

    static func absoluteURL(forStoredPath storedPath: String) -> URL {
        documentsDirectory().appendingPathComponent(storedPath)
    }

    private static func attachmentsDirectory() -> URL {
        let directory = documentsDirectory().appendingPathComponent(attachmentsDirectoryName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    private static func storedPath(forFilename filename: String) -> String {
        "\(attachmentsDirectoryName)/\(filename)"
    }

    private static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }
}
