import SwiftUI

struct ClubAccessView: View {
    @ObservedObject var accessStore: ClubAccessStore
    @State private var invitationCode = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AppIconImage(size: 96, cornerRadius: 22).accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text("Club access").font(.largeTitle.bold()).foregroundStyle(HomeColors.navy)
                    Text("Enter the invitation code supplied by your sailing club. No member account or email address is required.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 12) {
                    invitationField
                    if let message = accessStore.message { Label(message, systemImage: "exclamationmark.circle.fill").font(.callout).foregroundStyle(.red) }
                    Button(accessStore.isWorking ? "Contacting club…" : "Activate club") {
                        Task { await accessStore.activate(invitationCode: invitationCode) }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(HomeColors.navy)
                    .frame(maxWidth: .infinity).disabled(accessStore.isWorking || invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20).background(HomeColors.card).clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
            .frame(maxWidth: 440).padding(.horizontal, 24).padding(.vertical, 56).frame(maxWidth: .infinity)
        }
        .background(HomeColors.background.ignoresSafeArea())
    }

    @ViewBuilder private var invitationField: some View {
        #if os(iOS)
        TextField("Invitation code", text: $invitationCode)
            .textInputAutocapitalization(.characters).autocorrectionDisabled().textFieldStyle(.roundedBorder)
        #else
        TextField("Invitation code", text: $invitationCode)
            .autocorrectionDisabled().textFieldStyle(.roundedBorder)
        #endif
    }
}
