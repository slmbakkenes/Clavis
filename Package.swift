// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Clavis",
  platforms: [.macOS(.v14)],
  targets: [
    // Pure logic: no AppKit, fully unit-testable.
    .target(name: "ClavisCore"),
    // The app: AppKit shell, SwiftUI content, OS integrations.
    .executableTarget(
      name: "Clavis",
      dependencies: ["ClavisCore"],
      linkerSettings: [
        .linkedFramework("Carbon"),
        .linkedFramework("AppKit"),
      ]
    ),
    .testTarget(
      name: "ClavisCoreTests",
      dependencies: ["ClavisCore"],
      resources: [.copy("Fixtures")]
    ),
    // App-level logic (search rows, model, key routing) that needs the
    // executable's types but no running UI.
    .testTarget(name: "ClavisTests", dependencies: ["Clavis"]),
  ],
  swiftLanguageModes: [.v6]
)
