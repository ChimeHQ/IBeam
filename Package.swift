// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "IBeam",
	platforms: [
		.macOS(.v12),
		.macCatalyst(.v15),
		.iOS(.v15),
		.visionOS(.v1),
	],
	products: [
		.library(name: "IBeam", targets: ["IBeam"]),
	],
	dependencies: [
		.package(url: "https://github.com/ChimeHQ/Ligature", revision: "2da2638e59eef2aa6ce0e2078d4e075267bacd4b"),
		.package(url: "https://github.com/ChimeHQ/KeyCodes", from: "1.0.3"),
	],
	targets: [
		.target(name: "IBeam", dependencies: ["KeyCodes", "Ligature"]),
		.testTarget(name: "IBeamTests", dependencies: ["IBeam", "Ligature"]),
	]
)
