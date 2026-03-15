import SwiftUI
import MultipeerConnectivity

/// Local trade: exchange shards with a nearby device over Multipeer. Both enter amount to give; on confirm, exchange is applied.
struct TradeView: View {
    let viewModel: LabViewModel
    let multipeer: MultipeerService
    let onDismiss: () -> Void

    @State private var myOffer: Int = 0
    @State private var theirOffer: Int? = nil
    @State private var tradeApplied = false
    @State private var lastProcessedMessage: String = ""
    @State private var isHosting = false

    private var myShards: Int { viewModel.profile.evolutionShards }
    private var canConfirm: Bool {
        guard let to = theirOffer, myOffer > 0, to > 0,
              myOffer <= myShards else { return false }
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
                            if theirOffer != nil {
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
            Button("Send offer") {
                guard myOffer > 0, myOffer <= myShards else { return }
                multipeer.send("TRADE_OFFER|\(myOffer)")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.brandCyan)
            .disabled(myOffer <= 0 || myOffer > myShards)
            .accessibilityHint("Sends your shard offer to the other device")
        }
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let to = theirOffer {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Theme.brandCyan)
                    Text("Exchange: You give \(myOffer), they give \(to)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
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
                    .accessibilityHint("Finalizes the exchange of shards with the other device")
                } else if tradeApplied {
                    Text("Trade complete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }
            }
        }
    }

    private func processReceived(_ message: String) {
        guard message != lastProcessedMessage else { return }
        let parts = message.split(separator: "|").map { String($0) }
        if parts.first == "TRADE_OFFER", parts.count >= 2, let amount = Int(parts[1]) {
            theirOffer = amount
            lastProcessedMessage = message
        } else if parts.first == "TRADE_CONFIRM", parts.count >= 3,
                  let senderGive = Int(parts[1]), let senderReceive = Int(parts[2]) {
            guard !tradeApplied, let myO = theirOffer.flatMap({ _ in myOffer > 0 ? myOffer : nil }) else { return }
            if senderGive == theirOffer && senderReceive == myO {
                viewModel.profile.evolutionShards -= myO
                viewModel.profile.evolutionShards += senderGive
                SaveSystem.saveProfile(viewModel.profile)
                tradeApplied = true
                lastProcessedMessage = message
            }
        }
    }

    private func confirmTrade() {
        guard let to = theirOffer, canConfirm else { return }
        viewModel.profile.evolutionShards -= myOffer
        viewModel.profile.evolutionShards += to
        SaveSystem.saveProfile(viewModel.profile)
        multipeer.send("TRADE_CONFIRM|\(myOffer)|\(to)")
        tradeApplied = true
    }
}
