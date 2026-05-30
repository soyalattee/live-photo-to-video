//
//  TemplateIntroRenderSupport.swift
//  auto-photos
//
//  Created by Codex on 5/23/26.
//

import UIKit

struct TemplateIntroRenderedTextOverlay {
    let overlay: TemplateAnimatedTextOverlay
    let frame: CGRect
    let image: UIImage?
}

enum TemplateIntroRenderSupport {
    static let defaultRenderSize = CGSize(width: 1080, height: 1920)

    static func textLayouts(
        for overlays: [TemplateAnimatedTextOverlay],
        renderSize: CGSize = defaultRenderSize
    ) -> [TemplateIntroRenderedTextOverlay] {
        var renderedOverlays: [TemplateIntroRenderedTextOverlay] = []

        for overlay in overlays where overlay.endTime > overlay.startTime {
            var frame = textFrame(for: overlay, renderSize: renderSize)

            if overlay.stacksBelowPreviousText, let previousFrame = renderedOverlays.last?.frame {
                let stackedFrames = frameStackedBelow(
                    frame,
                    previousFrame: previousFrame,
                    renderSize: renderSize
                )
                frame = stackedFrames.current

                if let previousIndex = renderedOverlays.indices.last {
                    let previousOverlay = renderedOverlays[previousIndex]
                    renderedOverlays[previousIndex] = TemplateIntroRenderedTextOverlay(
                        overlay: previousOverlay.overlay,
                        frame: stackedFrames.previous,
                        image: previousOverlay.image
                    )
                }
            }

            renderedOverlays.append(
                TemplateIntroRenderedTextOverlay(
                    overlay: overlay,
                    frame: frame,
                    image: textImage(for: overlay, size: frame.size)
                )
            )
        }

        return renderedOverlays
    }

    static func iconFrame(
        for icon: TemplateIntroIcon,
        renderSize: CGSize = defaultRenderSize
    ) -> CGRect {
        let iconSize = CGFloat(icon.baseSize * 2.4 * icon.scaleMultiplier)
        let layerSize = CGSize(width: iconSize, height: iconSize)
        return CGRect(
            x: (renderSize.width * CGFloat(icon.position.normalizedX)) - (layerSize.width / 2),
            y: (renderSize.height * CGFloat(icon.position.normalizedY)) - (layerSize.height / 2),
            width: layerSize.width,
            height: layerSize.height
        )
    }

    static func videoLayerFrame(
        fromTopLeftFrame frame: CGRect,
        renderSize: CGSize = defaultRenderSize
    ) -> CGRect {
        CGRect(
            x: frame.minX,
            y: renderSize.height - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    private static func textFrame(
        for overlay: TemplateAnimatedTextOverlay,
        renderSize: CGSize
    ) -> CGRect {
        let horizontalMargin = renderSize.width * CGFloat(max((1 - overlay.normalizedMaxWidthRatio) / 2, 0.05))
        let maxWidth = renderSize.width - (horizontalMargin * 2)
        let maxHeight = renderSize.height * 0.34
        let resolvedFont = AppFontCatalog.uiKitFont(
            overlay.fontName,
            size: CGFloat(overlay.fontSize),
            fallbackWeight: .bold
        )
        let attributedText = makeAttributedText(
            text: overlay.text,
            font: resolvedFont,
            color: overlay.color.uiColor,
            shadow: overlay.shadow.map(makeShadow),
            glow: overlay.glow.map(makeGlow),
            stroke: overlay.stroke,
            lineBreakMode: .byWordWrapping,
            lineHeightMultiple: overlay.normalizedLineHeightMultiple
        )
        let textInsets = makeTextInsets(
            for: overlay.shadow.map(makeShadow),
            glow: overlay.glow.map(makeGlow),
            stroke: overlay.stroke
        )
        let measuredHeight = min(
            ceil(
                attributedText.boundingRect(
                    with: CGSize(
                        width: max(maxWidth - textInsets.left - textInsets.right, 1),
                        height: .greatestFiniteMagnitude
                    ),
                    options: NSStringDrawingOptions([.usesLineFragmentOrigin, .usesFontLeading]),
                    context: nil as NSStringDrawingContext?
                ).height
            ) + textInsets.top + textInsets.bottom,
            maxHeight
        )

        return CGRect(
            x: horizontalMargin,
            y: min(
                max((renderSize.height * CGFloat(overlay.position.normalizedY)) - (measuredHeight / 2), 48),
                renderSize.height - measuredHeight - 48
            ),
            width: maxWidth,
            height: measuredHeight
        )
    }

    private static func frameStackedBelow(
        _ frame: CGRect,
        previousFrame: CGRect,
        renderSize: CGSize
    ) -> (current: CGRect, previous: CGRect) {
        let gap = renderSize.height * 0.012
        var previousFrame = previousFrame
        var stackedFrame = frame
        stackedFrame.origin.y = previousFrame.maxY + gap

        let overflow = stackedFrame.maxY - (renderSize.height - 48)
        if overflow > 0 {
            let adjustment = min(overflow, max(previousFrame.minY - 48, 0))
            stackedFrame.origin.y -= adjustment
            previousFrame.origin.y -= adjustment
        }

        return (current: stackedFrame, previous: previousFrame)
    }

    private static func textImage(
        for overlay: TemplateAnimatedTextOverlay,
        size: CGSize
    ) -> UIImage? {
        let resolvedFont = AppFontCatalog.uiKitFont(
            overlay.fontName,
            size: CGFloat(overlay.fontSize),
            fallbackWeight: .bold
        )
        return makeAdvancedTextImage(
            text: overlay.text,
            font: resolvedFont,
            color: overlay.color.uiColor,
            size: size,
            shadow: overlay.shadow.map(makeShadow),
            glow: overlay.glow.map(makeGlow),
            stroke: overlay.stroke,
            fillExpansion: overlay.fillExpansion,
            lineHeightMultiple: overlay.normalizedLineHeightMultiple,
            referenceText: overlay.text
        )
    }

    private static func makeShadow(from shadow: TemplateTextShadow) -> NSShadow {
        let renderedShadow = NSShadow()
        renderedShadow.shadowColor = shadow.color.uiColor
        renderedShadow.shadowOffset = CGSize(width: CGFloat(shadow.offsetX), height: CGFloat(shadow.offsetY))
        renderedShadow.shadowBlurRadius = CGFloat(shadow.blurRadius)
        return renderedShadow
    }

    private static func makeGlow(from glow: TemplateTextGlow) -> NSShadow {
        let renderedGlow = NSShadow()
        renderedGlow.shadowColor = glow.color.uiColor.withAlphaComponent(CGFloat(glow.opacity))
        renderedGlow.shadowOffset = .zero
        renderedGlow.shadowBlurRadius = CGFloat(glow.blurRadius)
        return renderedGlow
    }

    private static func makeAttributedText(
        text: String,
        font: UIFont,
        color: UIColor,
        shadow: NSShadow?,
        glow: NSShadow?,
        stroke: TemplateTextStroke?,
        lineBreakMode: NSLineBreakMode,
        lineHeightMultiple: Double
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = lineBreakMode
        paragraphStyle.lineHeightMultiple = CGFloat(lineHeightMultiple)
        let fixedLineHeight = font.pointSize * CGFloat(lineHeightMultiple)
        paragraphStyle.minimumLineHeight = fixedLineHeight
        paragraphStyle.maximumLineHeight = fixedLineHeight

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]

        if let shadow {
            attributes[.shadow] = shadow
        }

        if let glow {
            attributes[.strokeColor] = UIColor.clear
            attributes[.strokeWidth] = 0
            attributes[.shadow] = shadow ?? glow
        }

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func makeAdvancedTextImage(
        text: String,
        font: UIFont,
        color: UIColor,
        size: CGSize,
        shadow: NSShadow?,
        glow: NSShadow?,
        stroke: TemplateTextStroke?,
        fillExpansion: Double?,
        lineHeightMultiple: Double,
        referenceText: String
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale

        let baseAttributedText = makeAttributedText(
            text: text,
            font: font,
            color: color,
            shadow: shadow,
            glow: nil,
            stroke: stroke,
            lineBreakMode: .byWordWrapping,
            lineHeightMultiple: lineHeightMultiple
        )
        let outlineAttributedText = stroke.map {
            makeAttributedText(
                text: text,
                font: font,
                color: $0.color.uiColor,
                shadow: nil,
                glow: nil,
                stroke: nil,
                lineBreakMode: .byWordWrapping,
                lineHeightMultiple: lineHeightMultiple
            )
        }
        let glowAttributedText = glow.map {
            makeAttributedText(
                text: text,
                font: font,
                color: color.withAlphaComponent(0.96),
                shadow: $0,
                glow: $0,
                stroke: stroke,
                lineBreakMode: .byWordWrapping,
                lineHeightMultiple: lineHeightMultiple
            )
        }
        let referenceAttributedText = makeAttributedText(
            text: referenceText,
            font: font,
            color: color,
            shadow: shadow,
            glow: glow,
            stroke: stroke,
            lineBreakMode: .byWordWrapping,
            lineHeightMultiple: lineHeightMultiple
        )
        let textInsets = makeTextInsets(for: shadow, glow: glow, stroke: stroke)

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let insetBounds = CGRect(
                x: textInsets.left,
                y: textInsets.top,
                width: size.width - textInsets.left - textInsets.right,
                height: size.height - textInsets.top - textInsets.bottom
            )
            let measuredRect = referenceAttributedText.boundingRect(
                with: insetBounds.size,
                options: NSStringDrawingOptions([.usesLineFragmentOrigin, .usesFontLeading]),
                context: nil as NSStringDrawingContext?
            )
            let drawRect = CGRect(
                x: insetBounds.minX,
                y: insetBounds.minY + max((insetBounds.height - measuredRect.height) / 2, 0),
                width: insetBounds.width,
                height: min(measuredRect.height, insetBounds.height)
            )

            if let stroke, let outlineAttributedText {
                drawOutlinedText(
                    outlineAttributedText,
                    in: drawRect,
                    radius: CGFloat(stroke.width)
                )
            }
            glowAttributedText?.draw(
                with: drawRect,
                options: NSStringDrawingOptions([.usesLineFragmentOrigin, .usesFontLeading]),
                context: nil as NSStringDrawingContext?
            )
            if let fillExpansion, fillExpansion > 0 {
                drawExpandedText(
                    baseAttributedText,
                    in: drawRect,
                    expansion: CGFloat(fillExpansion)
                )
            }
            baseAttributedText.draw(
                with: drawRect,
                options: NSStringDrawingOptions([.usesLineFragmentOrigin, .usesFontLeading]),
                context: nil as NSStringDrawingContext?
            )
        }
    }

    private static func drawOutlinedText(
        _ text: NSAttributedString,
        in rect: CGRect,
        radius: CGFloat
    ) {
        let step = max(radius / 3, 1.4)
        var currentRadius = step

        while currentRadius <= radius {
            let diagonalOffset = currentRadius * 0.707
            let offsets = [
                CGPoint(x: -currentRadius, y: 0),
                CGPoint(x: currentRadius, y: 0),
                CGPoint(x: 0, y: -currentRadius),
                CGPoint(x: 0, y: currentRadius),
                CGPoint(x: -diagonalOffset, y: -diagonalOffset),
                CGPoint(x: diagonalOffset, y: -diagonalOffset),
                CGPoint(x: -diagonalOffset, y: diagonalOffset),
                CGPoint(x: diagonalOffset, y: diagonalOffset),
            ]

            for offset in offsets {
                text.draw(
                    with: rect.offsetBy(dx: offset.x, dy: offset.y),
                    options: NSStringDrawingOptions([.usesLineFragmentOrigin, .usesFontLeading]),
                    context: nil as NSStringDrawingContext?
                )
            }

            currentRadius += step
        }
    }

    private static func drawExpandedText(
        _ text: NSAttributedString,
        in rect: CGRect,
        expansion: CGFloat
    ) {
        let offsets = [
            CGPoint(x: -expansion, y: 0),
            CGPoint(x: expansion, y: 0),
            CGPoint(x: 0, y: -expansion),
            CGPoint(x: 0, y: expansion),
            CGPoint(x: -expansion * 0.7, y: -expansion * 0.7),
            CGPoint(x: expansion * 0.7, y: -expansion * 0.7),
            CGPoint(x: -expansion * 0.7, y: expansion * 0.7),
            CGPoint(x: expansion * 0.7, y: expansion * 0.7),
        ]

        for offset in offsets {
            text.draw(
                with: rect.offsetBy(dx: offset.x, dy: offset.y),
                options: NSStringDrawingOptions([.usesLineFragmentOrigin, .usesFontLeading]),
                context: nil as NSStringDrawingContext?
            )
        }
    }

    private static func makeTextInsets(
        for shadow: NSShadow?,
        glow: NSShadow?,
        stroke: TemplateTextStroke?
    ) -> UIEdgeInsets {
        let shadowOffset = shadow?.shadowOffset ?? .zero
        let glowBlurRadius = glow?.shadowBlurRadius ?? 0
        let shadowBlurRadius = shadow?.shadowBlurRadius ?? 0
        let strokePadding = stroke.map { CGFloat(abs($0.width) * 1.8) } ?? 0
        let horizontalPadding = max(20, abs(shadowOffset.width) + shadowBlurRadius + glowBlurRadius + strokePadding + 12)
        let verticalPadding = max(12, abs(shadowOffset.height) + shadowBlurRadius + glowBlurRadius + strokePadding + 12)
        return UIEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
    }
}

private extension ColorToken {
    var uiColor: UIColor {
        UIColor(
            red: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: 1
        )
    }
}
