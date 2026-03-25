import SwiftUI
import MultipeerConnectivity

/// Local trade: exchange Evolution Shards and/or Creator Cards over Multipeer (Academy Arena).
struct TradeView: View {
    let viewModel: LabViewModel
    let multipeer: MultipeerService
    let onDismiss: () -> Void

    @State private var myOffer: Int = 0
    /// What the peer last advertised (from `TRADE_OFFER`).
    @State private var theirOfferShards: Int?
    /// Empty string means the peer did not include a Creator Card.
    @State private var theirOfferCardId: String = ""
    /// Empty string means no card included in the offer.
    @State private var myOfferCardId: String = ""
    @State private var tradeApplied = false
    @State private var lastProcessedMessage: String = ""
    @State private var isHosting = false

    private var myShards: Int { viewModel.profile.evolutionShards }
    private var ownedCards: [CreatorCard] {
        CreatorCard.catalog.filter { viewModel.profile.ownsCard($0.id) }
    }

    private var canConfirm: Bool {
        guard let to = theirOfferShards, myOffer > 0, to > 0,
              myOffer <= myShards else { return false }
        if !myOfferCardId.isEmpty {
            guard viewModel.profile.ownsCard(myOfferCardId) else { return false }
        }
        return !tradeApplied
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !multipeer.isConnected {
                            connectionPrompt
                        } else {
                            myBalanceCard
                            offerSection
                            if theirOfferShards != nil {
                                matchSection
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        multipeer.stop()
                        onDismiss()
                    }
                    .foregroundStyle(Theme.brandBlue)
                }
            }
            .onChange(of: multipeer.lastReceivedMessage) { _, msg in
                processReceived(msg)
            }
            .onDisappear {
                multipeer.stop()
            }
        }
    }

    private var connectionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Connect to a nearby device")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Open Trade on the other device and host or join. Use Local Play in Arena to connect first, or host/join here with service \"trade\".")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack(spacing: 12) {
                Button {
                    isHosting = true
                    multipeer.startHosting(gameId: "trade")
                } label: {
                    Text("Host")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.brandCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Host trade")
                .accessibilityHint("Start a trade session for a nearby device to join")
                Button {
                    isHosting = false
                    multipeer.startBrowsing(gameId: "trade")
                } label: {
                    Text("Join")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.brandCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Join trade")
                .accessibilityHint("Find and join a trade session from a nearby device")
            }
            .padding(.top, 8)
            if !isHosting && !multipeer.discoveredPeers.isEmpty {
                Text("Nearby traders")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 16)
                ForEach(multipeer.discoveredPeers) { peer in
                    Button {
                        multipeer.invite(peer: peer.peerId)
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(Theme.brandCyan)
                            Text(peer.peerId.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("Connect")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.brandCyan)
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var myBalanceCard: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.brandCyan)
            Text("Your shards: \(myShards)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(16)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var offerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You give (shards)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                Stepper("\(myOffer)", value: $myOffer, in: 0...max(0, myShards), step: 5)
                    .labelsHidden()
                Text("\(myOffer)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(12)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !ownedCards.isEmpty {
                Text("Optional: include a Creator Card")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Card to trade", selection: $myOfferCardId) {
                    Text("None").tag("")
                    ForEach(ownedCards) { card in
                        Text(card.title).tag(card.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.brandCyan)
            }

            Button("Send offer") {
                guard myOffer > 0, myOffer <= myShards else { return }
                if !myOfferCardId.isEmpty, !viewModel.profile.ownsCard(myOfferCardId) { return }
                let cardPart = myOfferCardId.isEmpty ? "NONE" : myOfferCardId
                multipeer.send("TRADE_OFFER|\(myOffer)|\(cardPart)")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.brandCyan)
            .disabled(myOffer <= 0 || myOffer > myShards)
            .accessibilityHint("Sends your shard and optional card offer to the other device")
        }
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let to = theirOfferShards {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Theme.brandCyan)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exchange: You give \(myOffer) shards, they give \(to) shards")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        if !theirOfferCardId.isEmpty {
                            Text("Their card: \(cardTitle(for: theirOfferCardId))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        if !myOfferCardId.isEmpty {
                            Text("Your card: \(cardTitle(for: myOfferCardId))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.brandCyan.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                if canConfirm {
                    Button("Confirm trade") {
                        confirmTrade()
                    }
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.brandCyan)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .buttonStyle(.plain)
                    .accessibilityHint("Finalizes the exchange with the other device")
                } else if tradeApplied {
                    Text("Trade complete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }
            }
        }
    }

    private func cardTitle(for id: String) -> String {
        CreatorCard.catalog.first(where: { $0.id == id })?.title ?? id
    }

    private func processReceived(_ message: String) {
        guard message != lastProcessedMessage else { return }
        let parts = message.split(separator: "|").map { String($0) }
        if parts.first == "TRADE_OFFER", parts.count >= 2, let amount = Int(parts[1]) {
            theirOfferShards = amount
            theirOfferCardId = parts.count >= 3 ? (normalizedCard(parts[2]) ?? "") : ""
            lastProcessedMessage = message
        } else if parts.first == "TRADE_CONFIRM", parts.count >= 5,
                  let senderGive = Int(parts[1]), let senderRecv = Int(parts[2]) {
            let senderGiveCard = normalizedCard(parts[3])
            let senderRecvCard = normalizedCard(parts[4])
            guard !tradeApplied, let theirS = theirOfferShards else { return }
            let myCardOpt = myOfferCardId.isEmpty ? nil : myOfferCardId
            let theirCardOpt = theirOfferCardId.isEmpty ? nil : theirOfferCardId
            if senderGive == theirS && senderRecv == myOffer
                && senderGiveCard == theirCardOpt && senderRecvCard == myCardOpt {
                if viewModel.applyAcademyTrade(
                    giveShards: myOffer,
                    receiveShards: theirS,
                    giveCardId: myCardOpt,
                    receiveCardId: theirCardOpt
                ) {
                    tradeApplied = true
                    lastProcessedMessage = message
                }
            }
        } else if parts.first == "TRADE_CONFIRM", parts.count >= 3,
                  let senderGive = Int(parts[1]), let senderReceive = Int(parts[2]) {
            guard !tradeApplied, let myO = theirOfferShards, myOffer > 0 else { return }
            if senderGive == myO && senderReceive == myOffer {
                if viewModel.applyAcademyTrade(
                    giveShards: myOffer,
                    receiveShards: myO,
                    giveCardId: nil,
                    receiveCardId: nil
                ) {
                    tradeApplied = true
                    lastProcessedMessage = message
                }
            }
        }
    }

    private func confirmTrade() {
        guard let to = theirOfferShards, canConfirm else { return }
        let myC = myOfferCardId.isEmpty ? "NONE" : myOfferCardId
        let theirC = theirOfferCardId.isEmpty ? "NONE" : theirOfferCardId
        let myCardOpt = myOfferCardId.isEmpty ? nil : myOfferCardId
        let theirCardOpt = theirOfferCardId.isEmpty ? nil : theirOfferCardId
        if viewModel.applyAcademyTrade(
            giveShards: myOffer,
            receiveShards: to,
            giveCardId: myCardOpt,
            receiveCardId: theirCardOpt
        ) {
            multipeer.send("TRADE_CONFIRM|\(myOffer)|\(to)|\(myC)|\(theirC)")
            tradeApplied = true
        }
    }

    private func normalizedCard(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.uppercased() == "NONE" { return nil }
        return t
    }
}
