import SpendCore
import SwiftUI

extension SpendCategory {
    var color: Color {
        switch self {
        case .groceries: return .green
        case .fastFood: return .orange
        case .restaurants: return .red
        case .coffee: return .brown
        case .gas: return .yellow
        case .transport: return .blue
        case .shopping: return .pink
        case .onlineShopping: return .purple
        case .entertainment: return .indigo
        case .subscriptions: return .teal
        case .health: return .mint
        case .personalCare: return .cyan
        case .utilities: return Color(red: 0.45, green: 0.45, blue: 0.55)
        case .travel: return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .other: return .gray
        }
    }
}

struct CategoryIcon: View {
    let category: SpendCategory
    var body: some View {
        Image(systemName: category.symbolName)
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(category.color.gradient, in: RoundedRectangle(cornerRadius: 8))
    }
}

enum Money {
    static var defaultCurrency: String { Locale.current.currency?.identifier ?? "USD" }
    static func format(_ value: Decimal, _ currency: String = defaultCurrency) -> String {
        value.formatted(.currency(code: currency))
    }
}
