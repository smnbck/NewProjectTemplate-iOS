#!/usr/bin/env beak run --path

// MARK: - Script Dependencies
// beak: kareman/SwiftShell @ .upToNextMajor(from: "4.1.2")
// beak: onevcat/Rainbow @ .upToNextMajor(from: "3.1.2")

import Foundation
import Rainbow
import SwiftShell

// MARK: - Runnable Tasks
/// Installs all tools and dependencies required to build the project.
public func install() throws {
    try execute(bash: "tools install")
    try execute(bash: "deps install")
    try openXcodeProject()
}

/// Initially configures the project from the NewProjectTemplate from GitHub. Only use once when creating a new project.
public func setup(name: String, orga: String) throws {
    // delete unnecessary files
    for fileToDelete in ["README.md", "LICENSE", "Logo.png"] {
        try execute(bash: "rm \(fileToDelete)")
    }

    // rename sample files to be actual files
    for sampleFile in ["README.md.sample", "LICENSE.sample"] {
        try execute(bash: "mv \(sampleFile) \(sampleFile.replacingOccurrences(of: ".sample", with: ""))")
    }

    // replace name & orga in project file contents
    try replaceFileContentOccurences(of: "NewProjectTemplate", with: name)
    try replaceFileContentOccurences(of: "Jamit Labs GmbH", with: orga)

    // rename files with new name
    try execute(bash: "mv NewProjectTemplate.xcodeproj \(name).xcodeproj")

    // install tools, update dependencies & open project
    try execute(bash: "tools install")
    try execute(bash: "deps update")
    try openXcodeProject()
}

/// Looks up the correct namespaces and adds them in IB files. Use only after namespacing all Image Asset folders.
public func namespaceImages() throws {
    try namespaceAssetCatalog(ofType: .images)
}

/// Looks up the correct namespaces and adds them in IB files. Use only after namespacing all Color Asset folders.
public func namespaceColors() throws {
    try namespaceAssetCatalog(ofType: .colors)
}

/// Describes the two asset catalog types available.
private enum AssetCatalogType {
    case images
    case colors

    var title: String {
        return self == .images ? "Images" : "Colors"
    }

    var fileExtension: String {
        return self == .images ? "imageset" : "colorset"
    }
}

/// Looks up the correct namespaces and adds them in IB files. Use only after namespacing all Asset folders.
private func namespaceAssetCatalog(ofType assetCatalogType: AssetCatalogType) throws {
    let assetPaths = run(bash: "LC_ALL=C find App/Resources/\(assetCatalogType.title).xcassets/ -type d -name *.\(assetCatalogType.fileExtension)").stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
    print("Found \(assetPaths.count) assets to namespace.")
    for assetPath in assetPaths {
        let assetName = assetPath.components(separatedBy: "/").last!
            .replacingOccurrences(of: ".\(assetCatalogType.fileExtension)", with: "")
        print(assetName)
        let namespacedAssetPath = assetPath.components(separatedBy: ".xcassets//").last!
            .replacingOccurrences(of: ".\(assetCatalogType.fileExtension)", with: "").replacingOccurrences(of: "/", with: "\\/")

        for fileExtension in ["storyboard", "xib"] {
            try execute(bash: "LC_ALL=C find App/Sources/ -type f -name *.\(fileExtension) -exec sed -i '' 's/=\"\(assetName)\"/=\"\(namespacedAssetPath)\"/g' {} \\;")
        }
    }
}

// MARK: - Helpers
private func execute(bash command: String) throws {
    print("⏳ Executing '\(command.italic.lightYellow)'".bold)
    try runAndPrint(bash: command)
}

private func replaceFileContentOccurences(of stringToReplace: String, with replacement: String) throws {
    try execute(bash: "LC_ALL=C find . -d 1 -type f -exec sed -i '' 's/\(stringToReplace)/\(replacement)/g' {} \\;")

    for subfolder in ["App", "Tests", "UITests", "NewProjectTemplate.xcodeproj"] {
        try execute(bash: "LC_ALL=C find . -regex '\\./\(subfolder)/.*' -type f -exec sed -i '' 's/\(stringToReplace)/\(replacement)/g' {} \\;")
    }
}

private func openXcodeProject() throws {
    let xcodeWorkspaces = run(bash: "find . -d 1 -regex '.*\\.xcworkspace' -type d").stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
    let xcodeProjects = run(bash: "find . -d 1 -regex '.*\\.xcodeproj' -type d").stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }

    if let workspacePath = xcodeWorkspaces.first {
        try execute(bash: "open \(workspacePath)")
    } else if let projectPath = xcodeProjects.first {
        try execute(bash: "open \(projectPath)")
    } else {
        print("Could not find any Xcode Project for automatic opening.")
    }
}
