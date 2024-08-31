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
		.package(url: "https://github.com/ChimeHQ/Ligature", revision: "b184b82dd4c68327ed37257d1b60fc9f41a50042"),
		.package(url: "https://github.com/ChimeHQ/KeyCodes", from: "1.0.3"),
	],
	targets: [
		.target(name: "IBeam", dependencies: ["KeyCodes", "Ligature"]),
		.testTarget(name: "IBeamTests", dependencies: ["IBeam", "Ligature"]),
	]
)
