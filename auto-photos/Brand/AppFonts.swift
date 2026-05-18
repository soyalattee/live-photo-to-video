//
//  AppFonts.swift
//  auto-photos
//
//  Created by Codex on 5/13/26.
//

import SwiftUI
import UIKit
import CoreText

enum AppFontName {
    static let kukdeTopokkiLight = "SDKukdetopokki-aLt"
    static let kukdeTopokkiBold = "SDKukdetopokki-bBd"
    static let kotraHope = "KOTRAHOPE"
}

enum AppFontCatalog {
    private static let bundledFonts: [(fontName: String, resourceName: String, fileExtension: String)] = [
        (AppFontName.kukdeTopokkiLight, "SDKukdetopokki-aLt", "otf"),
        (AppFontName.kukdeTopokkiBold, "SDKukdetopokki-bBd", "otf"),
        (AppFontName.kotraHope, "KOTRA HOPE", "otf"),
    ]
    private static var registeredFontNames = Set<String>()

    static func swiftUIFont(_ fontName: String, size: CGFloat) -> Font {
        .custom(fontName, size: size)
    }

    static func registerBundledFonts() {
        for font in bundledFonts {
            _ = registerFont(named: font.fontName, resourceName: font.resourceName, fileExtension: font.fileExtension)
        }
    }

    static func uiKitFont(
        _ fontName: String,
        size: CGFloat,
        fallbackWeight: UIFont.Weight = .regular
    ) -> UIFont {
        registerBundledFonts()

        return UIFont(name: fontName, size: size)
            ?? makeRegisteredFont(fontName: fontName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: fallbackWeight)
    }

    @discardableResult
    private static func registerFont(named fontName: String, resourceName: String, fileExtension: String) -> String? {
        if registeredFontNames.contains(fontName) {
            return fontName
        }

        guard let url = bundleFontURL(resourceName: resourceName, fileExtension: fileExtension) else {
            return nil
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)

        guard
            let provider = CGDataProvider(url: url as CFURL),
            let cgFont = CGFont(provider),
            let postScriptName = cgFont.postScriptName as String?
        else {
            return nil
        }

        registeredFontNames.insert(fontName)
        registeredFontNames.insert(postScriptName)
        return postScriptName
    }

    private static func makeRegisteredFont(fontName: String, size: CGFloat) -> UIFont? {
        guard let bundledFont = bundledFonts.first(where: { $0.fontName == fontName }) else {
            return nil
        }

        guard let postScriptName = registerFont(
            named: bundledFont.fontName,
            resourceName: bundledFont.resourceName,
            fileExtension: bundledFont.fileExtension
        ) else {
            return nil
        }

        return UIFont(name: postScriptName, size: size)
    }

    private static func bundleFontURL(resourceName: String, fileExtension: String) -> URL? {
        Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
            ?? Bundle.main.url(forResource: resourceName, withExtension: fileExtension, subdirectory: "Resources/Fonts")
    }
}
