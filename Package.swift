// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FujiBackup",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: PTP packets, device info, backup files. No camera needed, fully unit-tested.
        .target(name: "FujiBackupCore"),
        // The app: camera link (ImageCaptureCore) and SwiftUI interface.
        .executableTarget(name: "FujiBackup", dependencies: ["FujiBackupCore"]),
        .testTarget(name: "FujiBackupCoreTests", dependencies: ["FujiBackupCore"]),
    ]
)
