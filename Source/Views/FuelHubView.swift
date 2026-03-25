import SwiftUI

// MARK: - Fuel the Freeway — Hub
// Entry for Fuel tab: Nutrition Dashboard + Cookbook. RPG-style fuel for Bio-Electric Freeway and fascia.

struct FuelHubView: View {
    var viewModel: LabViewModel
    @State private var showCookbook: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NutritionDashboardView(viewModel: viewModel)
                cookbookEntryCard
            }
            .padding(.bottom, 32)
        }
        .background(Theme.deepBlack)
        .sheet(isPresented: $showCookbook) {
            NavigationStack {
                FuelCookbookView()
            }
        }
    }

    private var cookbookEntryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.brandCyan)
                Text("VERTICAL VELOCITY COOKBOOK")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.brandCyan)
            }
            Text("Fascial hydration broths, CNS ignition snacks, and the Dstrkt Protocol. Export ingredients to cart when DoorDash is connected.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
            Button {
                showCookbook = true
            } label: {
                HStack {
                    Text("Open Cookbook")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(16)
                .background(Theme.brandBlue.opacity(0.12))
                .foregroundStyle(Theme.brandBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open cookbook")
        }
        .padding(16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.brandCyan.opacity(0.2), lineWidth: 1))
        )
    }
}
