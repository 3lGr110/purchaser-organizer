import Foundation

/// Top-level spending buckets. Raw values are persisted, so never rename them —
/// add new cases instead.
public enum SpendCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case groceries
    case fastFood
    case restaurants
    case coffee
    case gas
    case transport
    case shopping
    case onlineShopping
    case entertainment
    case subscriptions
    case health
    case personalCare
    case utilities
    case travel
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .groceries: return "Groceries"
        case .fastFood: return "Fast Food"
        case .restaurants: return "Restaurants & Bars"
        case .coffee: return "Coffee & Cafés"
        case .gas: return "Gas & Fuel"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .onlineShopping: return "Online Shopping"
        case .entertainment: return "Entertainment"
        case .subscriptions: return "Subscriptions"
        case .health: return "Health & Pharmacy"
        case .personalCare: return "Personal Care"
        case .utilities: return "Bills & Utilities"
        case .travel: return "Travel"
        case .other: return "Other"
        }
    }

    /// SF Symbol name used by the UI.
    public var symbolName: String {
        switch self {
        case .groceries: return "cart.fill"
        case .fastFood: return "takeoutbag.and.cup.and.straw.fill"
        case .restaurants: return "fork.knife"
        case .coffee: return "cup.and.saucer.fill"
        case .gas: return "fuelpump.fill"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .onlineShopping: return "shippingbox.fill"
        case .entertainment: return "ticket.fill"
        case .subscriptions: return "repeat.circle.fill"
        case .health: return "cross.case.fill"
        case .personalCare: return "scissors"
        case .utilities: return "bolt.fill"
        case .travel: return "airplane"
        case .other: return "questionmark.circle.fill"
        }
    }
}
