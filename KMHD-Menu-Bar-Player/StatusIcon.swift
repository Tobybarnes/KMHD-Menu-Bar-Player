import Cocoa

/// Menu bar icons, drawn in code so they stay sharp on every screen.
enum StatusIcon {
    static func image(useLogo: Bool, playing: Bool) -> NSImage? {
        let image: NSImage?
        if useLogo {
            image = logo(filled: playing)
        } else {
            image = NSImage(systemSymbolName: playing ? "radio.fill" : "radio",
                            accessibilityDescription: playing ? "KMHD playing" : "KMHD")
        }
        image?.isTemplate = true
        return image
    }

    /// A "KMHD" badge: outlined when stopped, solid with the letters cut out while playing.
    static func logo(filled: Bool) -> NSImage {
        let text = "KMHD" as NSString
        let font = NSFont.systemFont(ofSize: 9, weight: .heavy)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textWidth = ceil(text.size(withAttributes: attributes).width)
        let size = NSSize(width: textWidth + 8, height: 15)

        let image = NSImage(size: size, flipped: false) { rect in
            let box = NSBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), xRadius: 3, yRadius: 3)
            // Centre the capitals: the draw origin sits on the descender line.
            let origin = NSPoint(x: (rect.width - textWidth) / 2,
                                 y: (rect.height - font.capHeight) / 2 + font.descender)

            if filled {
                NSColor.black.setFill()
                box.fill()
                if let context = NSGraphicsContext.current?.cgContext {
                    context.saveGState()
                    context.setBlendMode(.destinationOut)
                    text.draw(at: origin, withAttributes: attributes)
                    context.restoreGState()
                }
            } else {
                NSColor.black.setStroke()
                box.lineWidth = 1.5
                box.stroke()
                text.draw(at: origin, withAttributes: attributes)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
