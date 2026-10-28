import SwiftUI

struct SummaryPaneView: View {
    @ObservedObject var controller: JobController
    let readingStyle: ReadingStyleSettings
    @State private var isEditing = false
    @State private var summaryDraft = ""
    @State private var loadedSummaryURL: URL?
    @State private var isRegenerateConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear {
            loadDraft(force: true)
        }
        .onDisappear {
            Task { await controller.flushPendingSummarySave() }
        }
        .onChange(of: controller.snapshot.summaryURL) { _ in
            Task { await controller.flushPendingSummarySave() }
            loadDraft(force: true)
        }
        .onChange(of: controller.snapshot.summaryText) { _ in
            loadDraft(force: false)
        }
        .onChange(of: controller.summaryRequestStatus) { status in
            if status?.state == .inProgress {
                isEditing = false
            }
        }
        .alert("Regenerate summary?", isPresented: $isRegenerateConfirmationPresented) {
            Button("Regenerate", role: .destructive) {
                isEditing = false
                controller.flushPendingSummarySaveSynchronously()
                controller.regenerateSummaryDiscardingExisting()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This discards the existing summary and regenerates it with the cloud model.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let requestStatus = controller.visibleSummaryRequestStatus(for: controller.selectedLibraryItem) {
                summaryRequestStatusView(requestStatus)
            } else if !controller.snapshot.summarySource.isEmpty {
                Text("Source: \(controller.snapshot.summarySource)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let item = controller.selectedLibraryItem {
                summaryHeaderButton(
                    systemName: item.isRead ? "checkmark.circle.fill" : "checkmark.circle",
                    foregroundColor: item.isRead ? .accentColor : .secondary,
                    help: item.isRead ? "Mark unread" : "Mark read"
                ) {
                    controller.markRead(!item.isRead, for: item)
                }
            }
            summaryHeaderButton(
                systemName: isEditing ? "eye" : "pencil",
                help: isEditing ? "Preview summary" : "Edit Markdown",
                disabled: controller.snapshot.summaryURL == nil || isSummaryRequestInProgress
            ) {
                if isEditing {
                    Task { await controller.flushPendingSummarySave() }
                }
                isEditing.toggle()
                if isEditing {
                    loadDraft(force: true)
                }
            }
            summaryHeaderButton(
                systemName: "arrow.clockwise",
                help: "Regenerate summary with the cloud API",
                disabled: !controller.isCloudSummaryConfigured || !canRegenerateSummary || isSummaryRequestInProgress
            ) {
                if hasExistingSummary {
                    isRegenerateConfirmationPresented = true
                } else {
                    isEditing = false
                    controller.flushPendingSummarySaveSynchronously()
                    controller.regenerateSummaryDiscardingExisting()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func summaryHeaderButton(
        systemName: String,
        foregroundColor: Color = .secondary,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(AppButtonStyle(iconOnly: true, foregroundColor: foregroundColor))
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(help)
    }

    private func summaryRequestStatusView(_ status: SummaryRequestStatus) -> some View {
        HStack(spacing: 6) {
            switch status.state {
            case .inProgress:
                AppProgressSpinner()
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            Text(status.message)
                .font(.caption)
                .foregroundStyle(status.state == .failure ? .red : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(minWidth: 0, maxWidth: 360, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        if isEditing && !isSummaryRequestInProgress {
            AppTextEditor(text: summaryDraftBinding, mode: .code)
        } else {
            SimpleMarkdownView(text: previewText, style: readingStyle)
        }
    }

    private var previewText: String {
        controller.snapshot.summaryText
    }

    private var canRegenerateSummary: Bool {
        controller.canGenerateSummary(for: controller.selectedLibraryItem)
    }

    private var hasExistingSummary: Bool {
        !controller.snapshot.summaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isSummaryRequestInProgress: Bool {
        controller.visibleSummaryRequestStatus(for: controller.selectedLibraryItem)?.state == .inProgress
    }

    private var summaryDraftBinding: Binding<String> {
        Binding(
            get: { summaryDraft },
            set: { newValue in
                guard newValue != summaryDraft else { return }
                summaryDraft = newValue
                controller.saveCurrentSummaryMarkdown(newValue)
            }
        )
    }

    private func loadDraft(force: Bool) {
        let summaryURL = controller.snapshot.summaryURL
        guard force || !isEditing else { return }
        guard force || loadedSummaryURL != summaryURL || summaryDraft != controller.snapshot.summaryText else { return }
        summaryDraft = controller.snapshot.summaryText
        loadedSummaryURL = summaryURL
        if summaryURL == nil {
            isEditing = false
        }
    }
}
