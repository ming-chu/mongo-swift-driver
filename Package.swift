// swift-tools-version:4.0
import PackageDescription
let package = Package(
    name: "MongoSwift",
    products: [
        .library(name: "MongoSwift", targets: ["MongoSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/mongodb/swift-bson", from: "1.0.0"),
        .package(url: "https://github.com/mongodb/swift-mongoc", from: "1.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "7.0.3")
    ],
    targets: [
        .target(name: "MongoSwift", dependencies: ["libmongoc", "libbson"]),
        .testTarget(name: "MongoSwiftTests", dependencies: ["MongoSwift", "Nimble"]),
        .testTarget(name: "MongoSwiftBenchmarks", dependencies: ["MongoSwift"])
    ]
)
