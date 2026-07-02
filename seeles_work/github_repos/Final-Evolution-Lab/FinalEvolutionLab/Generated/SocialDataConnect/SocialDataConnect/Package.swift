// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SocialDataConnect",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "SocialDataConnect",
            targets: ["SocialDataConnect"]),
    ],
    dependencies: [
      
        .package(url: "https://github.com/firebase/data-connect-ios-sdk", from: "11.11.0"),
      
    ],
    targets: [
        .target(
            name: "SocialDataConnect",
            dependencies: [
              .product(name:"FirebaseDataConnect", package:"data-connect-ios-sdk")
            ],
            path: "Sources"
        )
    ]
)

