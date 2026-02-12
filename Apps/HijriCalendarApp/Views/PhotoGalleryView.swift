import SwiftUI
import UIKit
import HijriCalendarCore

struct PhotoGalleryView: View {
    @Binding var reminder: HijriReminder
    @Environment(\.editMode) private var editMode
    @State private var selection: PhotoSelection?

    private var photos: [Attachment] {
        reminder.attachments.filter { $0.type == .photo }
    }

    var body: some View {
        Group {
            if photos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                    Text("No photos yet")
                        .font(.headline)
                    Text("Add photos from the reminder editor.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .padding()
            } else if editMode?.wrappedValue == .active {
                List {
                    ForEach(photos) { photo in
                        PhotoListRow(attachment: photo)
                    }
                    .onMove(perform: movePhotos)
                    .onDelete(perform: deletePhotos)
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 96), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(photos) { photo in
                            Button {
                                selection = PhotoSelection(id: photo.id)
                            } label: {
                                PhotoThumbnailView(attachment: photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Photos")
        .toolbar {
            if !photos.isEmpty {
                EditButton()
            }
        }
        .sheet(item: $selection) { selection in
            PhotoViewerView(reminder: $reminder, selectedPhotoID: selection.id)
        }
    }

    private func deletePhotos(at offsets: IndexSet) {
        let idsToDelete = offsets.compactMap { index in
            photos.indices.contains(index) ? photos[index].id : nil
        }
        reminder.attachments.removeAll { idsToDelete.contains($0.id) }
    }

    private func movePhotos(from source: IndexSet, to destination: Int) {
        var reordered = photos
        reordered.move(fromOffsets: source, toOffset: destination)
        applyPhotoOrder(reordered)
    }

    private func applyPhotoOrder(_ reordered: [Attachment]) {
        guard reordered.count == photos.count else { return }
        var photoIndex = 0
        reminder.attachments = reminder.attachments.map { attachment in
            guard attachment.type == .photo else { return attachment }
            let updated = reordered[photoIndex]
            photoIndex += 1
            return updated
        }
    }
}

private struct PhotoSelection: Identifiable {
    let id: UUID
}

private struct PhotoThumbnailView: View {
    let attachment: Attachment
    let size: CGFloat

    init(attachment: Attachment, size: CGFloat = 96) {
        self.attachment = attachment
        self.size = size
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.15))
            if let image = AttachmentImageLoader.uiImage(for: attachment) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

private struct PhotoListRow: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnailView(attachment: attachment, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.displayName ?? "Photo")
                    .font(.headline)
                if let path = attachment.path {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PhotoViewerView: View {
    @Binding var reminder: HijriReminder
    @State private var selectedPhotoID: UUID
    @Environment(\.dismiss) private var dismiss

    init(reminder: Binding<HijriReminder>, selectedPhotoID: UUID) {
        _reminder = reminder
        _selectedPhotoID = State(initialValue: selectedPhotoID)
    }

    private var photos: [Attachment] {
        reminder.attachments.filter { $0.type == .photo }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                TabView(selection: $selectedPhotoID) {
                    ForEach(photos) { photo in
                        PhotoFullView(attachment: photo)
                            .tag(photo.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        deleteSelectedPhoto()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private func deleteSelectedPhoto() {
        let currentPhotos = photos
        guard let currentIndex = currentPhotos.firstIndex(where: { $0.id == selectedPhotoID }) else { return }
        let deletedID = selectedPhotoID
        reminder.attachments.removeAll { $0.id == deletedID }

        let remaining = photos
        guard !remaining.isEmpty else {
            dismiss()
            return
        }

        let newIndex = min(currentIndex, remaining.count - 1)
        selectedPhotoID = remaining[newIndex].id
    }
}

private struct PhotoFullView: View {
    let attachment: Attachment

    var body: some View {
        ZStack {
            if let image = AttachmentImageLoader.uiImage(for: attachment) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Unable to load photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.black)
    }
}

private enum AttachmentImageLoader {
    static func uiImage(for attachment: Attachment) -> UIImage? {
        guard let path = attachment.path else { return nil }
        return UIImage(contentsOfFile: path)
    }
}
