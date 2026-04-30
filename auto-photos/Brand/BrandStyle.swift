//
//  BrandStyle.swift
//  auto-photos
//
//  Created by Codex on 4/30/26.
//

import SwiftUI
import UIKit

enum BrandPalette {
    static let ink = Color(red: 0.18, green: 0.16, blue: 0.16)
    static let inkSoft = Color(red: 0.29, green: 0.25, blue: 0.24)
    static let ivory = Color(red: 0.98, green: 0.97, blue: 0.95)
    static let cream = Color(red: 0.95, green: 0.92, blue: 0.88)
    static let sand = Color(red: 0.85, green: 0.79, blue: 0.73)
    static let cocoa = Color(red: 0.49, green: 0.41, blue: 0.38)
    static let line = Color.black.opacity(0.08)
    static let shadow = Color.black.opacity(0.12)
}

enum BrandLogoAsset {
    static let resourceName = "IMG_8015"
    static let fileExtension = "JPG"

    static var uiImage: UIImage? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }
}

struct BrandLogoView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let uiImage = BrandLogoAsset.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(BrandPalette.ink)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: size * 0.28, weight: .semibold))
                            .foregroundStyle(BrandPalette.ivory)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(BrandPalette.line, lineWidth: 1)
        )
        .shadow(color: BrandPalette.shadow, radius: 20, y: 10)
    }
}
