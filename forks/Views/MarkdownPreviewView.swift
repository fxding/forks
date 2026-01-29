import SwiftUI

struct MarkdownPreviewView: View {
    let filePath: String
    @State private var content: String = ""
    @State private var error: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load file")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(.init(content))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .navigationTitle(URL(fileURLWithPath: filePath).lastPathComponent)
        .onAppear {
            loadContent()
        }
    }
    
    private func loadContent() {
        do {
            content = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
