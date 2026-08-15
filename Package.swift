// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SixFourChess",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SixFourChess",
            targets: ["SixFourChess"]),
    ],
    targets: [
        .target(
            name: "SixFourChess",
            path: "SixFourChess/SixFourChess/Sources")
    ]
)
