// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Radix",
  platforms: [.macOS(.v14)],
  targets: [
    // Pure logic: no AppKit, fully unit-testable.
    .target(name: "RadixCore"),
    // The app: AppKit shell, SwiftUI content, OS integrations.
    .executableTarget(
      name: "Radix",
      dependencies: ["RadixCore"],
      linkerSettings: [
        .linkedFramework("Carbon"),
        .linkedFramework("AppKit"),
      ]
    ),
    .testTarget(
      name: "RadixCoreTests",
      dependencies: ["RadixCore"],
      resources: [.copy("Fixtures")]
    ),
    // App-level logic (search rows, model, key routing) that needs the
    // executable's types but no running UI.
    .testTarget(name: "RadixTests", dependencies: ["Radix"]),
  ],
  swiftLanguageModes: [.v6]
)
