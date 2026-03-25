import Foundation

struct VaultResource {
    let title: String
    let description: String
    let url: URL
    let icon: String
    let promoCode: String?
}

struct VaultResources {
    static let videos: [VaultResource] = [
        VaultResource(
            title: "Bonds Bounce Blueprint",
            description: "The master overview of vertical jump architecture.",
            url: SafeURL.make("https://youtu.be/hrlGbS0r-hM"),
            icon: "play.rectangle.fill",
            promoCode: nil
        ),
        VaultResource(
            title: "Bodyweight & Mobility",
            description: "Full exercise list with timestamps for structural integrity.",
            url: SafeURL.make("https://youtu.be/q1HLjLbhS2s"),
            icon: "figure.flexibility",
            promoCode: nil
        ),
        VaultResource(
            title: "Plyometric Exercises",
            description: "Comprehensive reactive power drills with timestamps.",
            url: SafeURL.make("https://youtu.be/pqyxTY85x4U"),
            icon: "figure.jumprope",
            promoCode: nil
        ),
        VaultResource(
            title: "Final Evolution Fitness",
            description: "Master exercise list for the complete training system.",
            url: SafeURL.make("https://youtu.be/J037GG99GT0"),
            icon: "flame.fill",
            promoCode: nil
        ),
        VaultResource(
            title: "Bonds Bounce Overview",
            description: "The original vertical jump architecture breakdown.",
            url: SafeURL.make("https://youtu.be/dAoLYThf1bc"),
            icon: "play.circle.fill",
            promoCode: nil
        ),
    ]

    static let equipment: [VaultResource] = [
        VaultResource(
            title: "PJF Performance Bands",
            description: "Essential for multi-directional low anchor programming.",
            url: SafeURL.make("https://pjf-performance-shop.myshopify.com/?sca_ref=9885072.t2P8qJogGNMRly"),
            icon: "bandage.fill",
            promoCode: nil
        ),
        VaultResource(
            title: "The Total Body Board",
            description: "Advanced isometric and reactive training platform.",
            url: SafeURL.make("https://www.totalbodyboard.com/"),
            icon: "square.grid.3x3.fill",
            promoCode: "EBondJmp"
        ),
    ]
}
