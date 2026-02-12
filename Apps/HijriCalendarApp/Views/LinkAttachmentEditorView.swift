import SwiftUI
import HijriCalendarCore

struct LinkAttachmentEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var urlString: String = ""

    let onSave: (Attachment) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("Title (optional)", text: $title)
                    TextField("URL", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLink()
                    }
                    .disabled(!isValidURL)
                }
            }
        }
    }

    private var isValidURL: Bool {
        makeURL() != nil
    }

    private func makeURL() -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }

    private func saveLink() {
        guard let url = makeURL() else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = Attachment(
            type: .link,
            path: nil,
            url: url.absoluteString,
            displayName: name.isEmpty ? url.host ?? url.absoluteString : name
        )
        onSave(attachment)
        dismiss()
    }
}

#Preview {
    LinkAttachmentEditorView { _ in }
}
