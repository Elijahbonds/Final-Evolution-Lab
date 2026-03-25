// MARK: - RFD, GRF & Pop Force — User education sheet

import SwiftUI

struct BiomechanicsEducationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Understanding how you produce force helps you train smarter. These concepts drive your Lab metrics and Arena performance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    ForEach(BiomechanicsEducation.Concept.all) { concept in
                        conceptCard(concept)
                    }
                }
                .padding()
            }
            .background(Theme.deepBlack)
            .navigationTitle("Force & Movement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func conceptCard(_ concept: BiomechanicsEducation.Concept) -> some View {
        let isExpanded = expandedId == concept.id
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedId = isExpanded ? nil : concept.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: concept.iconName)
                        .font(.system(size: 22))
                        .foregroundStyle(concept.color)
                        .frame(width: 44, height: 44)
                        .background(concept.color.opacity(0.15))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(concept.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(concept.shortDefinition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(concept.color.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(concept.fullExplanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }
        }
    }
}
