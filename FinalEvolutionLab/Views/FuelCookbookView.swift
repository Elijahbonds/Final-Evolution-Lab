import SwiftUI

// MARK: - Vertical Velocity Cookbook
// Fascial Hydration Broths, CNS Ignition Snacks, Dstrkt Protocol. Instacart export placeholder.

struct FuelCookbookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: CookbookRecipe.RecipeCategory? = nil
    @State private var selectedRecipe: CookbookRecipe?
    @State private var showExportAlert: Bool = false
    @State private var copiedRecipeTitle: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerBlock
                categoryPills
                recipeList
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.deepBlack)
        .navigationTitle("Cookbook")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(Theme.brandCyan)
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailSheet(
                recipe: recipe,
                onExportToCart: { exportTapped(recipe) },
                onCopyList: { copyList(recipe) }
            )
        }
        .alert("Export to cart", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Instacart / Whole Foods integration coming soon. Use \"Copy list\" to paste ingredients elsewhere.")
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VERTICAL VELOCITY KITCHEN")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Theme.brandBlue)
            Text("Recipes for fascial hydration, CNS ignition, and the Dstrkt Protocol. Inspect ingredients; export to cart when available.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryPill(nil, label: "All")
                ForEach(CookbookRecipe.RecipeCategory.allCases, id: \.self) { cat in
                    categoryPill(cat, label: cat.rawValue)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func categoryPill(_ category: CookbookRecipe.RecipeCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.brandBlue.opacity(0.25) : Color.white.opacity(0.08))
                .foregroundStyle(isSelected ? Theme.brandBlue : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var recipeList: some View {
        let list = selectedCategory == nil
            ? FuelCookbook.recipes
            : FuelCookbook.recipes(for: selectedCategory!)
        return VStack(alignment: .leading, spacing: 12) {
            Text("RECIPES")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            ForEach(list) { recipe in
                recipeCard(recipe)
            }
        }
    }

    private func recipeCard(_ recipe: CookbookRecipe) -> some View {
        Button {
            selectedRecipe = recipe
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(recipe.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(recipe.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(recipe.category.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.brandBlue.opacity(0.15), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func exportTapped(_ recipe: CookbookRecipe) {
        if InstacartExportService.exportToCart(ingredientNames: recipe.ingredients, mealPlanName: recipe.title) != nil {
            // Would open URL
        } else {
            showExportAlert = true
        }
    }

    private func copyList(_ recipe: CookbookRecipe) {
        let text = InstacartExportService.groceryListText(ingredientNames: recipe.ingredients, title: recipe.title)
        UIPasteboard.general.string = text
        copiedRecipeTitle = recipe.title
    }
}

// MARK: - Recipe detail (ingredients, instructions, 3D Kitchen note, Export / Copy)

private struct RecipeDetailSheet: View {
    let recipe: CookbookRecipe
    let onExportToCart: () -> Void
    let onCopyList: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(recipe.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let sling = recipe.slingNote {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                            Text("Supports: \(sling)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    Section {
                        Text("Ingredients")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        ForEach(recipe.ingredients, id: \.self) { ing in
                            Text("• \(ing)")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.white)
                        }
                    }
                    Section {
                        Text("Instructions")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(recipe.instructions)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white)
                    }
                    HStack(spacing: 12) {
                        Button {
                            onCopyList()
                            dismiss()
                        } label: {
                            Label("Copy list", systemImage: "doc.on.doc")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        Button {
                            onExportToCart()
                        } label: {
                            Label("Export to cart", systemImage: "cart")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.brandBlue.opacity(0.2))
                                .foregroundStyle(Theme.brandBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Theme.deepBlack)
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
            }
        }
    }
}

// CookbookRecipe is Sendable but not Identifiable in the sense of Hashable for sheet(item:). We need Identifiable. It already has id. So we need to make it work with sheet(item:). Item must be Identifiable and Hashable. CookbookRecipe has id: String and is a struct - so it's Identifiable. But for sheet(item:) the type must be Optional and the binding is to that optional. So selectedRecipe: CookbookRecipe? and we need CookbookRecipe to be Identifiable. It has let id: String so it's Identifiable. Good.