import SwiftUI

struct AddSubscriptionSheet: View {
    @ObservedObject var controller: JobController
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isURLFocused: Bool
    @State private var isSubmitting = false
    @State private var submissionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Subscription")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                Text("Podcast or RSS URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Xiaoyuzhou, Apple Podcast, or RSS URL", text: $controller.subscriptionURLText)
                    .textFieldStyle(AppTextFieldStyle())
                    .focused($isURLFocused)
                    .disabled(isSubmitting)
            }
            HStack(spacing: 10) {
                Text("Group")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                groupMenu
                    .disabled(isSubmitting)
            }
            if let submissionError {
                Label(submissionError, systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(AppButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSubmitting)
                Button(action: submit) {
                    if isSubmitting {
                        AppProgressSpinner()
                    } else {
                        Label("Add", systemImage: "plus")
                    }
                }
                .buttonStyle(AppButtonStyle(variant: .prominent))
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
        }
        .padding(24)
        .frame(width: 480)
        .interactiveDismissDisabled(isSubmitting)
        .onAppear { isURLFocused = true }
    }

    private var canSubmit: Bool {
        !controller.subscriptionURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
            && !controller.isAddingSubscription
            && !controller.isRefreshingSubscriptions
            && !controller.stage.isRunning
    }

    private var groupMenu: some View {
        AppMenu {
            ForEach(controller.availableGroupNames, id: \.self) { groupName in
                Button(groupName) {
                    controller.subscriptionGroupName = groupName
                }
            }
        } label: {
            AppMenuLabel(title: controller.subscriptionGroupName, systemImage: "folder")
        }
    }

    private func submit() {
        guard canSubmit else { return }
        submissionError = nil
        isSubmitting = true
        controller.addSubscription { succeeded in
            isSubmitting = false
            if succeeded {
                dismiss()
            } else {
                submissionError = controller.message
            }
        }
    }
}
