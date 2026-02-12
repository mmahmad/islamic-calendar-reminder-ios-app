import Foundation
import HijriCalendarCore

enum AttachmentStorage {
    static func savePhotoData(_ data: Data) -> Attachment? {
        let directory = attachmentsDirectory()
        let filename = "photo-\(UUID().uuidString).dat"
        let url = directory.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: [.atomic])
            return Attachment(
                type: .photo,
                path: url.path,
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

        do {
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.copyItem(at: url, to: targetURL)
            return Attachment(
                type: .file,
                path: targetURL.path,
                displayName: filename
            )
        } catch {
            return nil
        }
    }

    private static func attachmentsDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("Attachments", isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }
}
