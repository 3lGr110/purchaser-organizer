import Foundation

/// Maps ISO 18245 Merchant Category Codes (provided by FinanceKit / bank data)
/// to our categories.
public enum MCCMapper {
    public static func category(for mcc: Int) -> SpendCategory? {
        switch mcc {
        case 5411, 5422, 5441, 5451, 5462, 5499: return .groceries
        case 5814: return .fastFood
        case 5811, 5812, 5813: return .restaurants
        case 5541, 5542, 5552, 5983: return .gas
        case 4111, 4112, 4121, 4131, 4784, 4789, 7511, 7523: return .transport
        case 3000...3299, 3351...3441, 3501...3999, 4411, 4511, 4582, 4722, 7011, 7012, 7512: return .travel
        case 4812, 4814, 4816, 4899, 4900: return .utilities
        case 5815, 5816, 5817, 5818, 5968: return .subscriptions
        case 5912, 5975, 5976, 8011...8099: return .health
        case 7230, 7297, 7298: return .personalCare
        case 7832, 7841, 7911, 7922, 7929, 7932, 7933, 7941, 7991, 7992, 7993, 7994, 7996, 7997, 7998, 7999:
            return .entertainment
        case 5964, 5965, 5966, 5967, 5969: return .onlineShopping
        case 5200...5399, 5600...5799, 5900...5999: return .shopping
        default: return nil
        }
    }
}
