import Foundation
import StoreKit

/// Owns the Us. Premium subscription: what's free, what's locked, and the
/// StoreKit 2 purchase/entitlement state.
///
/// Free tier: the first two quiz categories (Starters, Relationship) and the
/// How Well Do You Know Me? game. Everything else opens the paywall.
@MainActor
final class PremiumStore: ObservableObject {
    static let shared = PremiumStore()

    static let productID = "us.premium.monthly"

    /// Quiz categories playable without a subscription (backend catalog ids).
    static let freeQuizCategoryIDs: Set<String> = ["starters", "relationship"]
    /// Games playable without a subscription (`GameDef.id`).
    static let freeGameIDs: Set<String> = ["hwdykm"]

    @Published private(set) var isPremium = false
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        isPremium = Self.devUnlock
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Gating

    func isQuizCategoryLocked(_ categoryID: String) -> Bool {
        !isPremium && !Self.freeQuizCategoryIDs.contains(categoryID)
    }

    func isGameLocked(_ gameID: String) -> Bool {
        !isPremium && !Self.freeGameIDs.contains(gameID)
    }

    // MARK: - Display

    /// "€2.99" once StoreKit answers; the configured price until then, so the
    /// paywall never shows an empty slot.
    var displayPrice: String { product?.displayPrice ?? "€2.99" }

    var priceLine: String { "\(displayPrice) / month" }

    // MARK: - StoreKit

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            // Leave `product` nil — the paywall falls back to the static price
            // and surfaces the failure only if the user taps subscribe.
            product = nil
        }
    }

    /// Buys the subscription. Returns true when the user is entitled afterwards.
    @discardableResult
    func purchase() async -> Bool {
        errorMessage = nil
        if product == nil { await loadProduct() }
        guard let product else {
            errorMessage = "The subscription isn't available right now. Please try again later."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                    return isPremium
                }
                errorMessage = "We couldn't verify that purchase with the App Store."
                return false
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "Your purchase is waiting for approval. We'll unlock everything as soon as it goes through."
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Restores a subscription bought on another device / after a reinstall.
    func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        errorMessage = nil
        try? await AppStore.sync()
        await refreshEntitlement()
        if !isPremium {
            errorMessage = "No active subscription found on this Apple ID."
        }
    }

    func refreshEntitlement() async {
        if Self.devUnlock { isPremium = true; return }
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID else { continue }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }
            if transaction.revocationDate != nil { continue }
            entitled = true
        }
        isPremium = entitled
    }

    // MARK: - Dev override

    /// Debug-only switch (Settings → Premium) so the locked flows can be walked
    /// through without a sandbox purchase. Never consulted in release builds.
    static var devUnlock: Bool {
        get {
            #if DEBUG
            UserDefaults.standard.bool(forKey: "premium.devUnlock")
            #else
            false
            #endif
        }
        set { UserDefaults.standard.set(newValue, forKey: "premium.devUnlock") }
    }

    func setDevUnlock(_ on: Bool) {
        Self.devUnlock = on
        Task { await refreshEntitlement() }
    }
}
