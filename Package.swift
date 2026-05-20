// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentTerms",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AgentTerms", targets: ["AgentTerms"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "AgentTerms",
            dependencies: ["SwiftTerm"],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AgentTermsTests",
            dependencies: ["AgentTerms"],
            path: "Tests"
        )
    ]
)
