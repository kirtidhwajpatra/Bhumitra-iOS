import SwiftUI
import AVFoundation

/// High-performance seamless looping video player background for SwiftUI with speed control
public struct LoopingVideoBackgroundView: UIViewRepresentable {
    public let videoName: String
    public let videoExtension: String
    public let videoGravity: AVLayerVideoGravity
    public let playerBackgroundColor: UIColor
    public let playbackRate: Float
    
    public init(
        videoName: String = "onboarding_bg",
        videoExtension: String = "mp4",
        videoGravity: AVLayerVideoGravity = .resizeAspectFill,
        playerBackgroundColor: UIColor = .clear,
        playbackRate: Float = 1.0
    ) {
        self.videoName = videoName
        self.videoExtension = videoExtension
        self.videoGravity = videoGravity
        self.playerBackgroundColor = playerBackgroundColor
        self.playbackRate = playbackRate
    }
    
    public func makeUIView(context: Context) -> LoopingPlayerUIView {
        return LoopingPlayerUIView(
            videoName: videoName,
            videoExtension: videoExtension,
            videoGravity: videoGravity,
            playerBackgroundColor: playerBackgroundColor,
            playbackRate: playbackRate
        )
    }
    
    public func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.updateGravity(videoGravity)
        uiView.updateBackgroundColor(playerBackgroundColor)
        uiView.updatePlaybackRate(playbackRate)
    }
}

public final class LoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var playbackRate: Float = 1.0
    private var rateObserver: NSKeyValueObservation?
    
    init(
        videoName: String,
        videoExtension: String,
        videoGravity: AVLayerVideoGravity = .resizeAspectFill,
        playerBackgroundColor: UIColor = .clear,
        playbackRate: Float = 1.0
    ) {
        self.playbackRate = playbackRate
        super.init(frame: .zero)
        backgroundColor = playerBackgroundColor
        
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
        playerLayer.videoGravity = videoGravity
        layer.addSublayer(playerLayer)
        
        // Start playback and apply the custom playback speed
        player.play()
        if playbackRate != 1.0 {
            player.rate = playbackRate
        }
        
        // Ensure playback rate remains locked at the desired speed across looping cycles
        self.rateObserver = player.observe(\.rate, options: [.new]) { [weak self] observedPlayer, change in
            guard let self = self else { return }
            if observedPlayer.rate > 0 && observedPlayer.rate != self.playbackRate {
                observedPlayer.rate = self.playbackRate
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateGravity(_ gravity: AVLayerVideoGravity) {
        if playerLayer.videoGravity != gravity {
            playerLayer.videoGravity = gravity
        }
    }
    
    public func updateBackgroundColor(_ color: UIColor) {
        if backgroundColor != color {
            backgroundColor = color
        }
    }
    
    public func updatePlaybackRate(_ rate: Float) {
        if self.playbackRate != rate {
            self.playbackRate = rate
            if let p = queuePlayer, p.rate > 0 {
                p.rate = rate
            }
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
    
    deinit {
        rateObserver?.invalidate()
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
    }
}
