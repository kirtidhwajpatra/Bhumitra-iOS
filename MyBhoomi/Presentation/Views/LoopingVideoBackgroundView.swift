import SwiftUI
import AVFoundation

/// High-performance seamless looping video player background for SwiftUI
public struct LoopingVideoBackgroundView: UIViewRepresentable {
    public let videoName: String
    public let videoExtension: String
    
    public init(videoName: String = "onboarding_bg", videoExtension: String = "mp4") {
        self.videoName = videoName
        self.videoExtension = videoExtension
    }
    
    public func makeUIView(context: Context) -> LoopingPlayerUIView {
        return LoopingPlayerUIView(videoName: videoName, videoExtension: videoExtension)
    }
    
    public func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

public final class LoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    
    init(videoName: String, videoExtension: String) {
        super.init(frame: .zero)
        backgroundColor = .black
        
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            print("DEBUG: ⚠️ Video resource \(videoName).\(videoExtension) not found in bundle.")
            return
        }
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.actionAtItemEnd = .none
        
        self.playerLooper = AVPlayerLooper(player: player, templateItem: item)
        self.queuePlayer = player
        
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        
        player.play()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
    
    deinit {
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
    }
}
