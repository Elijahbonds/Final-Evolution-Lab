# Event Ticketing & Team Fundraising Module

This pass adds a live-events economy layer backed by Credits + Shards.

## What is implemented

### 1) Ticket Entity + Armory Tickets

File: `FinalEvolutionLab/Models/EventTicketing.swift`

- `EventTicket` contains:
  - `eventId`
  - `tier` (`GA`, `VIP`, `Virtual`)
  - `priceInCredits`
  - `priceInShards`
  - `shardBonusValue`
  - `qrPayload`
- QR payload format:
  - `fel://ticket/{eventId}/{ticketId}?owner={userId}`
- User-owned tickets are queryable via:
  - `LabViewModel.armoryTickets`

### 2) Team Fundraising Goals + Milestones

- `FundraisingGoal` linked to `TeamProfile`
- `FundraisingContribution` records ticket-purchase and donation sources
- Milestone unlock logic:
  - 50%: practice jersey reward stub
  - 100%: dunk show unlock stub
  - 100%: top donor receives Patron multiplier (5% shard multiplier)

### 3) Live Voting + Ticket-Holder Gating

- `LiveVotingSession` + `LiveVote` models
- Simulated socket service:
  - `FinalEvolutionLab/Services/LiveVotingSocketService.swift`
- `LabViewModel` methods:
  - `openLiveVoting(eventId:)`
  - `connectLiveVotingSocket(eventId:)`
  - `submitLiveVote(eventId:score:)`
  - `closeLiveVoting(eventId:)`
- Voting requires ticket ownership for the event.

### 4) Ticket Purchase Economy Rules

- Tickets can require Credits, Shards, or both (tier-specific pricing).
- Purchase grants shard bonus + rebate.
- Creator Card discount:
  - Owning the headliner creator card applies 10% credit discount.
- Referral rewards:
  - 5% shard bonus (ledgered by referrer ID).
- Hype train:
  - Every 10 tickets sold triggers shard reward for ticket holders.
- Golden ticket:
  - Every 100th ticket grants a legendary reward pack.

### 5) Persistence + Cloud Sync

- New state object: `EventHubState`
- Local persistence:
  - `SaveSystem.saveEventHub(_:)`
  - `SaveSystem.loadEventHub()`
- Cloud snapshot now includes `eventHub` with backward-compatible decoding.

## Key APIs (LabViewModel)

- `purchaseEventTicket(eventId:tier:referralSourceUserId:)`
- `donateToFundraisingGoal(goalId:creditsAmount:)`
- `topDonors(for:limit:)`
- `ticketPricing(for:tier:)`
- `referralLink(for:)`

## Seed Data

`EventTicketingSeedData.makeInitialState()` provides:
- 2 sample events
- Team profile
- Fundraising goal
- Ticket tier pricing
