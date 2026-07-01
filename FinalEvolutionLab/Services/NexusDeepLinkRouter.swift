import Foundation
import SwiftUI

struct IdentifiableURL: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
}

/// Centralized deep link routing service that handles universal links
/// matching finalevolutiongroup.com/creator-card/{id} and finalevolutiongroup.com/scan/{id}.
@Observable
@MainActor
final class NexusDeepLinkRouter {
    static let shared = NexusDeepLinkRouter()
    
    // Routing states
    var activeCardLink: CreatorCard? = nil
    var activeScanLink: Bool = false
    var prefilledSport: String? = nil
    var prefilledGoal: String? = nil
    var activeSafariURL: IdentifiableURL? = nil
    
    private init() {}
    
    /// Parses and routes a universal link.
    /// Returns true if the URL was successfully handled.
    func handle(url: URL) -> Bool {
        guard let host = url.host(), host.contains("finalevolutiongroup.com") else {
            return false
        }
        
        let pathComponents = url.pathComponents
        // pathComponents[0] is typically "/"
        // pathComponents[1] is the resource type ("creator-card" or "scan")
        // pathComponents[2] is the id
        
        guard pathComponents.count >= 3 else {
            return false
        }
        
        let resourceType = pathComponents[1]
        let resourceId = pathComponents[2]
        
        if resourceType == "creator-card" {
            // Find the card in the catalog
            if let card = CreatorCard.catalog.first(where: { $0.id == resourceId }) {
                self.activeCardLink = card
                self.activeScanLink = false
                self.activeSafariURL = nil
                return true
            }
        } else if resourceType == "scan" {
            // Pre-populate scan parameters
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                let queryItems = components.queryItems ?? []
                let sportItem = queryItems.first(where: { $0.name == "sport" })?.value
                let goalItem = queryItems.first(where: { $0.name == "goal" })?.value
                
                let mappedSport = mapIdToSport(resourceId)
                let mappedGoal = mapIdToGoal(resourceId)
                
                self.prefilledSport = sportItem ?? mappedSport
                self.prefilledGoal = goalItem ?? mappedGoal
            } else {
                self.prefilledSport = mapIdToSport(resourceId)
                self.prefilledGoal = mapIdToGoal(resourceId)
            }
            
            self.activeCardLink = nil
            self.activeScanLink = true
            self.activeSafariURL = nil
            return true
        } else if resourceType == "masterclass" {
            let card = CreatorCard.catalog.first(where: { $0.id == resourceId })
            let urlString = card?.masterclassURL ?? "https://finalevolutiongroup.com/masterclass/\(resourceId)"
            if let targetURL = URL(string: urlString) {
                self.activeSafariURL = IdentifiableURL(url: targetURL)
                self.activeCardLink = nil
                self.activeScanLink = false
                return true
            }
        }
        
        return false
    }
    
    private func mapIdToSport(_ id: String) -> String? {
        let lower = id.lowercased()
        if lower.contains("basketball") || lower == "hoops" {
            return "Basketball"
        } else if lower.contains("soccer") {
            return "Soccer"
        } else if lower.contains("football") || lower == "gridiron" {
            return "Football"
        } else if lower.contains("golf") {
            return "Golf"
        } else if lower.contains("baseball") {
            return "Baseball"
        }
        return nil
    }
    
    private func mapIdToGoal(_ id: String) -> String? {
        let lower = id.lowercased()
        if lower.contains("jump") || lower.contains("bounce") || lower == "vertical" {
            return "Jump Higher"
        } else if lower.contains("speed") || lower.contains("fast") {
            return "Get Faster"
        } else if lower.contains("power") || lower.contains("strength") {
            return "Build Power"
        }
        return nil
    }
}
