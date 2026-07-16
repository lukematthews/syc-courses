import SwiftUI

struct InstrumentAccessView: View {
    @EnvironmentObject private var accessStore: InstrumentAccessStore

    var body: some View {
        Group {
            if accessStore.hasAccess {
                NavigationOutputSettingsView()
            } else {
                paywall
            }
        }
        .navigationTitle("Instruments")
    }

    private var paywall: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(HomeColors.navy)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Instrument Integration")
                        .font(.largeTitle.bold())
                        .foregroundStyle(HomeColors.navy)
                        .multilineTextAlignment(.center)

                    Text("Connect SYC Courses to a supported NMEA Wi-Fi gateway.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 16) {
                    benefit("Receive boat position, speed, course and heading", icon: "arrow.down.circle")
                    benefit("Send active waypoint navigation data to instruments", icon: "paperplane.circle")
                    benefit("Use supported Actisense and Yacht Devices gateways", icon: "wifi")
                    benefit("One-time purchase", icon: "checkmark.seal")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 12) {
                    Button {
                        Task { await accessStore.purchase() }
                    } label: {
                        HStack {
                            if accessStore.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(purchaseButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(HomeColors.navy)
                    .disabled(accessStore.product == nil || accessStore.isPurchasing || accessStore.isLoading)

                    Button("Restore Purchases") {
                        Task { await accessStore.restorePurchases() }
                    }
                    .disabled(accessStore.isPurchasing || accessStore.isLoading)

                    if accessStore.product == nil, !accessStore.isLoading {
                        Button("Try Again") {
                            Task { await accessStore.refresh() }
                        }
                    }
                }

                if accessStore.isLoading {
                    ProgressView("Checking App Store")
                }

                if let errorMessage = accessStore.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Text("Requires compatible gateway hardware and gateway configuration. Instrument display and NMEA 2000 forwarding depend on the connected equipment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 520)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(HomeColors.background)
    }

    private var purchaseButtonTitle: String {
        if accessStore.isPurchasing {
            return "Purchasing…"
        }
        if let product = accessStore.product {
            return "Unlock for \(product.displayPrice)"
        }
        return "Unavailable"
    }

    private func benefit(_ text: String, icon: String) -> some View {
        Label {
            Text(text)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.blue)
        }
    }
}
