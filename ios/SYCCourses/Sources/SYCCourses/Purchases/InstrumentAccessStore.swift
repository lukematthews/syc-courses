import Foundation
import StoreKit

@MainActor
final class InstrumentAccessStore: ObservableObject {
    static let productID = "au.com.syc.courses.instrument-integration"

    @Published private(set) var product: Product?
    @Published private(set) var hasAccess = false
    @Published private(set) var isLoading = true
    @Published private(set) var isPurchasing = false
    @Published private(set) var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    deinit {
        updatesTask?.cancel()
    }

    func start() async {
        guard updatesTask == nil else { return }
        updatesTask = observeTransactionUpdates()
        await refresh()
    }

    func purchase() async {
        guard let product else {
            errorMessage = "Instrument Integration is not currently available for purchase."
            return
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case let .success(result):
                let transaction = try verified(result)
                await transaction.finish()
                await refreshEntitlement()
            case .pending:
                errorMessage = "The purchase is pending approval or payment confirmation."
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "The purchase could not be completed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !hasAccess {
                errorMessage = "No Instrument Integration purchase was found for this Apple Account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlement()
    }

    private func refreshEntitlement() async {
        var isEntitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil
            else { continue }
            isEntitled = true
            break
        }
        hasAccess = isEntitled
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard let transaction = try? Self.verified(result) else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }

    nonisolated private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value):
            value
        case .unverified:
            throw InstrumentPurchaseError.failedVerification
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        try Self.verified(result)
    }
}

private enum InstrumentPurchaseError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        "The App Store could not verify this purchase."
    }
}
