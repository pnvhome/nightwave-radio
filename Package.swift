// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "NightwaveRadio", platforms: [.macOS(.v14)], products: [.executable(name: "NightwaveRadio", targets: ["NightwaveRadio"])], targets: [
    .target(name: "RadioCore"),
    .executableTarget(name: "NightwaveRadio", dependencies: ["RadioCore"]),
    .testTarget(name: "RadioCoreTests", dependencies: ["RadioCore"])
])
