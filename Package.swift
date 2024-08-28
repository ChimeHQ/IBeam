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
		.package(url: "https://github.com/ChimeHQ/Ligature", branch: "main"),
	],
	targets: [
		.target(name: "IBeam", dependencies: ["Ligature"]),
		.testTarget(name: "IBeamTests", dependencies: ["IBeam"]),
	]
)
