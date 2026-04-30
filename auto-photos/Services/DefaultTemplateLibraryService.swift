//
//  DefaultTemplateLibraryService.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import Foundation

protocol TemplateLibraryService {
    func loadCustomTemplates() -> [VideoTemplate]
    func saveCustomTemplate(_ template: VideoTemplate) throws
    func importAudioTrack(from sourceURL: URL) throws -> TemplateAudioTrack
}

final class DefaultTemplateLibraryService: TemplateLibraryService {
    private let userDefaults: UserDefaults
    private let templatesKey = "custom-video-templates"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadCustomTemplates() -> [VideoTemplate] {
        guard let data = userDefaults.data(forKey: templatesKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([VideoTemplate].self, from: data)
        } catch {
            return []
        }
    }

    func saveCustomTemplate(_ template: VideoTemplate) throws {
        var templates = loadCustomTemplates()

        if let existingIndex = templates.firstIndex(where: { $0.id == template.id }) {
            templates[existingIndex] = template
        } else {
            templates.append(template)
        }

        let data = try JSONEncoder().encode(templates)
        userDefaults.set(data, forKey: templatesKey)
    }

    func importAudioTrack(from sourceURL: URL) throws -> TemplateAudioTrack {
        let fileManager = FileManager.default
        let extensionName = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let safeBaseName = sourceURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        let resourceName = "\(safeBaseName)-\(UUID().uuidString)"
        let destinationDirectory = TemplateStoragePaths.audioDirectory
        let destinationURL = destinationDirectory
            .appendingPathComponent(resourceName)
            .appendingPathExtension(extensionName)

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)

        let requiresSecurityScopedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if requiresSecurityScopedAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        return .imported(
            title: sourceURL.deletingPathExtension().lastPathComponent,
            resourceName: resourceName,
            fileExtension: extensionName
        )
    }
}
