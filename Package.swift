// swift-tools-version: 6.1

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
	traits: [
		.trait(name: "ViewSupport", description: "Enable support for NS/UITextView"),
		.default(enabledTraits: ["ViewSupport"])
	],
	dependencies: [
		.package(url: "https://github.com/ChimeHQ/Rearrange", from: "2.1.1"),
		.package(url: "https://github.com/ChimeHQ/Ligature", from: "0.1.1"),
	],
	targets: [
		.target(
			name: "IBeam",
			dependencies: [
				"Rearrange",
				.product(name: "Ligature", package: "Ligature", condition: .when(traits: ["ViewSupport"]))
			]
		),
		.testTarget(name: "IBeamTests", dependencies: ["IBeam"]),
	]
)
