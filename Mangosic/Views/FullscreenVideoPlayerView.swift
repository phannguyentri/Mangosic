import SwiftUI
import AVKit

// MARK: - Native AVPlayerViewController Wrapper
/// Uses iOS default video player UI with built-in fullscreen and orientation support
struct NativeFullscreenPlayer: UIViewControllerRepresentable {
    let player: AVPlayer?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = BackgroundFriendlyAVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        controller.allowsPictureInPicturePlayback = true
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        
        // Enable fullscreen behavior
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Only update if not in background "detached" state
        if let customController = uiViewController as? BackgroundFriendlyAVPlayerViewController, 
           customController.storedPlayer == nil {
            uiViewController.player = player
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            self._isPresented = isPresented
        }
        
        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            coordinator.animate(alongsideTransition: nil) { _ in
                self.isPresented = false
            }
        }
    }
}

// MARK: - Fullscreen Video Player View
/// Simple wrapper that presents native iOS video player in fullscreen
struct FullscreenVideoPlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            NativeFullscreenPlayer(
                player: viewModel.playerService.getPlayer(),
                isPresented: $isPresented
            )
            .ignoresSafeArea()
        }
        .onAppear {
            // Lock to landscape
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.orientationLock = .landscape
            }
            
            // Force rotation to landscape
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
                }
            }
        }
        .onDisappear {
            // Restore portrait
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.orientationLock = .all
            }
            
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    FullscreenVideoPlayerView(
        viewModel: PlayerViewModel(),
        isPresented: .constant(true)
    )
}
