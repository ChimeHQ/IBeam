// swift-tools-version: 6.0

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
		.package(url: "https://github.com/ChimeHQ/Rearrange", branch: "main"),
	],
	targets: [
		.target(name: "IBeam", dependencies: ["Rearrange"]),
		.testTarget(name: "IBeamTests", dependencies: ["IBeam"]),
	]
)
