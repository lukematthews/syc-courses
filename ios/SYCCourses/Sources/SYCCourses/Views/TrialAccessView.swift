import SwiftUI

struct TrialAccessView: View {
    @ObservedObject var accessStore: TrialAccessStore
    @State private var accessCode = ""
    @State private var errorMessage: String?
    @FocusState private var isAccessCodeFocused: Bool

    private var canSubmit: Bool {
        !accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AppIconImage(size: 96, cornerRadius: 22)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("SYC Courses Trial")
                        .font(.largeTitle.bold())
                        .foregroundStyle(HomeColors.navy)
                        .multilineTextAlignment(.center)

                    Text("Enter the access code supplied by Sandringham Yacht Club.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    accessCodeField

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }

                    Button("Unlock", action: submit)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(HomeColors.navy)
                        .frame(maxWidth: .infinity)
                        .disabled(!canSubmit)
                        .accessibilityHint("Checks the entered trial access code")
                }
                .padding(20)
                .background(HomeColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 24)
            .padding(.vertical, 56)
            .frame(maxWidth: .infinity)
        }
        .background(HomeColors.background.ignoresSafeArea())
        .onChange(of: accessCode) { _, _ in
            errorMessage = nil
        }
    }

    @ViewBuilder
    private var accessCodeField: some View {
        #if os(iOS)
        TextField("Access code", text: $accessCode)
            .textInputAutocapitalization(.characters)
            .keyboardType(.asciiCapable)
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .submitLabel(.go)
            .focused($isAccessCodeFocused)
            .onSubmit(submit)
            .accessibilityLabel("Access code")
        #else
        TextField("Access code", text: $accessCode)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .focused($isAccessCodeFocused)
            .onSubmit(submit)
            .accessibilityLabel("Access code")
        #endif
    }

    private func submit() {
        errorMessage = nil
        guard canSubmit else { return }

        if accessStore.unlock(with: accessCode) {
            isAccessCodeFocused = false
        } else {
            errorMessage = "That access code is not recognised."
        }
    }
}
