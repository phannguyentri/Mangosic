import SwiftUI
import AVKit

/// Video player wrapper for SwiftUI
struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false  // We use custom controls
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

/// Custom UIView that hosts AVPlayerLayer directly - no gestures at all
class PlayerLayerUIView: UIView {
    private var playerLayer: AVPlayerLayer
    
    var player: AVPlayer? {
        didSet {
            print("[DEBUG] PlayerLayerUIView - player set: \(player != nil)")
            playerLayer.player = player
        }
    }
    
    override init(frame: CGRect) {
        // Initialize player layer first
        playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
        
        super.init(frame: frame)
        
        backgroundColor = .black
        isUserInteractionEnabled = false  // Completely disable interaction
        layer.addSublayer(playerLayer)
        
        print("[DEBUG] PlayerLayerUIView initialized - isUserInteractionEnabled: \(isUserInteractionEnabled)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        print("[DEBUG] PlayerLayerUIView layoutSubviews - bounds: \(bounds)")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Return nil to pass all touches through
        print("[DEBUG] PlayerLayerUIView hitTest called - returning nil to pass through")
        return nil
    }
}

/// Fullscreen video player using AVPlayerLayer - absolutely no zoom or gestures
struct FullscreenVideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> PlayerLayerUIView {
        print("[DEBUG] FullscreenVideoPlayerRepresentable makeUIView called")
        let view = PlayerLayerUIView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {
        print("[DEBUG] FullscreenVideoPlayerRepresentable updateUIView called")
        uiView.player = player
    }
}
