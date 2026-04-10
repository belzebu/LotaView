#if os(iOS)
import UIKit
typealias PlatformView = UIView
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformView = NSView
typealias PlatformImage = NSImage
#endif
