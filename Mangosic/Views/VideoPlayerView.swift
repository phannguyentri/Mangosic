import SwiftUI
import AVKit

/// Video player wrapper for SwiftUI
/// Custom AVPlayerViewController that handles background playback correctly
class BackgroundFriendlyAVPlayerViewController: AVPlayerViewController {
    var storedPlayer: AVPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Prevent player view controller from managing audio session and now playing info
        // We handle this manually in AudioPlayerService
        self.updatesNowPlayingInfoCenter = false
        
        // Observe background/foreground events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleEnterBackground() {
        // Detach player from view controller to prevent auto-pause
        // But keep a reference to it
        if player != nil {
            print("📺 VideoPlayerView: Detaching player for background playback")
            storedPlayer = player
            player = nil
        }
    }
    
    @objc private func handleEnterForeground() {
        // Re-attach player when returning to foreground
        if let stored = storedPlayer {
            print("📺 VideoPlayerView: Re-attaching player")
            player = stored
            storedPlayer = nil
        }
    }
}

/// Video player wrapper for SwiftUI
struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = BackgroundFriendlyAVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false  // We use custom controls
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Only update if not in background "detached" state
        if let customController = uiViewController as? BackgroundFriendlyAVPlayerViewController, 
           customController.storedPlayer == nil {
            uiViewController.player = player
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        // Explicitly detach player when view is destroyed
        uiViewController.player = nil
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
