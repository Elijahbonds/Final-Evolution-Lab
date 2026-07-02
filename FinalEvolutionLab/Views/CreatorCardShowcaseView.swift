import SwiftUI

/// Full-screen showcase of a creator card — shows their IP, highlights, and movement signature.
struct CreatorCardShowcaseView: View {
    let card: CreatorCard
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var activeHighlight: Int? = nil

    var body: some View {
        ZStack {
            card.accentColor.opacity(0.04).ignoresSafeArea()
            LinearGradient(
                colors: [card.accentColor.opacity(0.15), Theme.deepBlack, Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    metricsStrip
                    taglineCard
                    miniBioSection
                    highlightsSection
                    movementSection
                    linksSection
                    activateSection
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55).delay(0.1)) { appeared = true }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [card.accentColor.opacity(0.25), card.accentColor.opacity(0.05)], center: .center, startRadius: 10, endRadius: 65))
                    .frame(width: 130, height: 130)

                Circle()
                    .strokeBorder(card.accentColor.opacity(appeared ? 0.5 : 0.1), lineWidth: 2)
                    .frame(width: 130, height: 130)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: appeared)

                Image(systemName: card.iconName)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(card.accentColor)
                    .shadow(color: card.accentColor.opacity(0.6), radius: 12)
                    .scaleEffect(appeared ? 1 : 0.5)
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text(card.creatorName.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(card.accentColor.opacity(0.8))
                    .tracking(4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Text(card.title)
                    .font(.system(size: 26, weight: .black))
                    .italic()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var metricsStrip: some View {
        HStack(spacing: 0) {
            metricCell(label: "PRQ", value: "+\(Int(card.metricsBoost.prqScore))", color: card.accentColor)
            Divider().frame(height: 36).background(Color.white.opacity(0.08))
            metricCell(label: "VERT", value: "+\(Int(card.metricsBoost.verticalPotential))\"", color: .yellow)
            Divider().frame(height: 36).background(Color.white.opacity(0.08))
            metricCell(label: "NEURAL", value: "+\(Int(card.metricsBoost.neuralDrive))", color: Color(red: 0.6, green: 0.2, blue: 1.0))
            Divider().frame(height: 36).background(Color.white.opacity(0.08))
            metricCell(label: "EFFIC.", value: "+\(Int(card.metricsBoost.efficiencyScore))", color: .green)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(card.accentColor.opacity(0.12), lineWidth: 1))
        )
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func metricCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var taglineCard: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(card.accentColor)
                .frame(width: 3)
                .cornerRadius(2)

            Text(card.resolvedShowcaseTagline)
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(card.accentColor.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 16).stroke(card.accentColor.opacity(0.15), lineWidth: 1)))
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .opacity(appeared ? 1 : 0)
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CREATOR IP · HIGHLIGHTS")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                ForEach(card.resolvedShowcaseHighlights.indices, id: \.self) { i in
                    highlightRow(text: card.resolvedShowcaseHighlights[i], index: i)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
    }

    private func highlightRow(text: String, index: Int) -> some View {
        let isActive = activeHighlight == index
        return Button {
            withAnimation(.spring(response: 0.3)) {
                activeHighlight = isActive ? nil : index
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isActive ? card.accentColor : card.accentColor.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(isActive ? .black : card.accentColor)
                }

                Text(text)
                    .font(.system(.subheadline, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.75))
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: isActive ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? card.accentColor : Color.white.opacity(0.2))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? card.accentColor.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isActive ? card.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var movementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MOVEMENT SIGNATURE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
                .padding(.leading, 4)

            HStack(spacing: 12) {
                movementStat(label: "STYLE", value: card.movementSignature.style.rawValue.uppercased(), color: card.accentColor)
                movementStat(label: "APEX", value: String(format: "×%.1f", card.movementSignature.jumpApex), color: .yellow)
                movementStat(label: "HANG", value: String(format: "×%.1f", card.movementSignature.hangTimeFactor), color: .cyan)
            }

            movementBar(label: "First Step Burst", value: card.movementSignature.firstStepBurst, maxValue: 2.0, color: .green)
            movementBar(label: "Limb Emission", value: card.movementSignature.limbEmission, maxValue: 1.0, color: card.movementSignature.trailColor)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
    }

    private func movementStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 0.5)))
    }

    private func movementBar(label: String, value: Double, maxValue: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", value)).font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * CGFloat(min(value / maxValue, 1.0)))
                        .animation(.spring(response: 0.6).delay(0.4), value: appeared)
                }
            }
            .frame(height: 6)
        }
    }

    private var miniBioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ABOUT")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
                .padding(.leading, 4)

            Text(card.resolvedMiniBio)
                .font(.system(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LINKS & RESOURCES")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                ForEach(card.resolvedLinks.indices, id: \.self) { i in
                    linkRow(card.resolvedLinks[i])
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
    }

    private func linkRow(_ link: CreatorLink) -> some View {
        Link(destination: URL(string: link.url) ?? URL(string: "https://finalevolutiongroup.com")!) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(card.accentColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: linkIcon(for: link.type))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(card.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.label)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(linkTypeLabel(for: link.type))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(card.accentColor.opacity(0.7))
                        .tracking(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(card.accentColor.opacity(0.12), lineWidth: 1))
            )
        }
    }

    private func linkIcon(for type: CreatorLink.LinkType) -> String {
        switch type {
        case .masterclass: return "book.fill"
        case .imdb:        return "film.fill"
        case .product:     return "bag.fill"
        case .website:     return "globe"
        case .youtube:     return "play.rectangle.fill"
        case .instagram:   return "camera.fill"
        case .spotify:     return "music.note"
        case .gallery:     return "photo.on.rectangle.angled"
        case .tiktok:      return "play.circle.fill"
        case .twitter:     return "at"
        case .podcast:     return "mic.fill"
        }
    }

    private func linkTypeLabel(for type: CreatorLink.LinkType) -> String {
        switch type {
        case .masterclass: return "MASTERCLASS"
        case .imdb:        return "IMDB"
        case .product:     return "PRODUCT"
        case .website:     return "WEBSITE"
        case .youtube:     return "YOUTUBE"
        case .instagram:   return "INSTAGRAM"
        case .spotify:     return "SPOTIFY"
        case .gallery:     return "ART GALLERY"
        case .tiktok:      return "TIKTOK"
        case .twitter:     return "TWITTER / X"
        case .podcast:     return "PODCAST"
        }
    }

    private var activateSection: some View {
        VStack(spacing: 12) {
            Text("AVATAR SKIN: \(card.metricsBoost.currentOutfit.uppercased())")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(card.accentColor.opacity(0.7))
                .tracking(2)

            Text("When this card is active, your avatar wears this creator's skin in every game mode.")
                .font(.system(.caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button { dismiss() } label: {
                Text("CLOSE")
                    .font(.system(.subheadline, weight: .black))
                    .foregroundStyle(card.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(card.accentColor.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(card.accentColor.opacity(0.3), lineWidth: 1))
                    .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 32)
        .opacity(appeared ? 1 : 0)
    }
}
