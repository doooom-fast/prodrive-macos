import SwiftUI
import AVFoundation
import AVKit
import AppKit

/// SwiftUI wrapper around an `AVPlayerLayer`. We don't use `AVKit.VideoPlayer`
/// because we want the bare frame painted into the layout — overlay HUD
/// elements need to composite over the video without AVKit's chrome.
struct AVPlayerLayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerNSView {
        let v = AVPlayerNSView()
        v.player = player
        return v
    }

    func updateNSView(_ nsView: AVPlayerNSView, context: Context) {
        nsView.player = player
    }
}

/// Custom NSView whose `layer` is an `AVPlayerLayer`. Resizes with the
/// SwiftUI parent and respects the gravity convention used in our HUD
/// designs (resizeAspect — full frame fit, no cropping).
final class AVPlayerNSView: NSView {

    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer = playerLayer
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
