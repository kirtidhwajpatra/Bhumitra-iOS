//
//  InteractionAnimatedGraphicView.swift
//  MyBhoomi
//
//  Reusable Interaction-Triggered Animation System for Onboarding & Location Selector.
//  - Keeps graphic completely static initially with no autoplay or continuous loop.
//  - Triggers smooth, single-play video animation on button click or Enter key.
//  - Respects accessibility prefers-reduced-motion.
//  - Built-in duplicate trigger debounce and safety transition timeouts.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Video Asset URL Resolver (Handles both NSDataAsset and Bundle resources)

public final class VideoAssetHelper {
    public static func url(forResource name: String, withExtension ext: String = "mp4") -> URL? {
        // 1. Check direct Bundle resources
        if let bundleURL = Bundle.main.url(forResource: name, withExtension: ext) {
            return bundleURL
        }
        
        // 2. Check NSDataAsset from Asset Catalog (.dataset)
        if let dataAsset = NSDataAsset(name: name) {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("\(name).\(ext)")
            
            // Check if file already exists with identical byte size
            if let existingData = try? Data(contentsOf: fileURL), existingData.count == dataAsset.data.count {
                return fileURL
            }
            
            do {
                try dataAsset.data.write(to: fileURL, options: .atomic)
                return fileURL
            } catch {
                print("[VideoAssetHelper] ⚠️ Failed to cache dataset to temp file: \(error.localizedDescription)")
            }
        }
        
        return nil
    }
}

// MARK: - Single-Play AVPlayer UIViewRepresentable

public struct InteractionVideoPlayerView: UIViewRepresentable {
    public let videoName: String
    public let videoExtension: String
    public let videoGravity: AVLayerVideoGravity
    public let isTriggered: Bool
    public let maxDuration: Double
    public let onFinish: () -> Void
    
    public init(
        videoName: String,
        videoExtension: String = "mp4",
        videoGravity: AVLayerVideoGravity = .resizeAspect,
        isTriggered: Bool,
        maxDuration: Double = 1.8,
        onFinish: @escaping () -> Void
    ) {
        self.videoName = videoName
        self.videoExtension = videoExtension
        self.videoGravity = videoGravity
        self.isTriggered = isTriggered
        self.maxDuration = maxDuration
        self.onFinish = onFinish
    }
    
    public func makeUIView(context: Context) -> InteractionPlayerUIView {
        return InteractionPlayerUIView(
            videoName: videoName,
            videoExtension: videoExtension,
            videoGravity: videoGravity,
            maxDuration: maxDuration,
            onFinish: onFinish
        )
    }
    
    public func updateUIView(_ uiView: InteractionPlayerUIView, context: Context) {
        uiView.updateGravity(videoGravity)
        if isTriggered {
            uiView.playOnce()
        }
    }
}

public final class InteractionPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var player: AVPlayer?
    private var itemDidPlayObserver: Any?
    private var hasTriggered = false
    private var hasFinished = false
    private let maxDuration: Double
    private let onFinish: () -> Void
    
    init(
        videoName: String,
        videoExtension: String,
        videoGravity: AVLayerVideoGravity,
        maxDuration: Double,
        onFinish: @escaping () -> Void
    ) {
        self.maxDuration = maxDuration
        self.onFinish = onFinish
        super.init(frame: .zero)
        backgroundColor = .clear
        
        guard let url = VideoAssetHelper.url(forResource: videoName, withExtension: videoExtension) else {
            print("[InteractionPlayerUIView] ⚠️ Video resource \(videoName).\(videoExtension) not found.")
            return
        }
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .pause
        avPlayer.preventsDisplaySleepDuringVideoPlayback = false
        
        // Ensure static first frame by pausing immediately at 0
        avPlayer.pause()
        avPlayer.seek(to: .zero)
        
        self.player = avPlayer
        playerLayer.player = avPlayer
        playerLayer.videoGravity = videoGravity
        playerLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(playerLayer)
        
        // Listen for end of single-play video
        itemDidPlayObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackFinished()
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
    
    public func playOnce() {
        guard !hasTriggered else { return }
        hasTriggered = true
        
        guard let player = player else {
            handlePlaybackFinished()
            return
        }
        
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            player.play()
            
            // Safety timeout: transition if video takes longer than maxDuration
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.maxDuration) { [weak self] in
                self?.handlePlaybackFinished()
            }
        }
    }
    
    private func handlePlaybackFinished() {
        guard !hasFinished else { return }
        hasFinished = true
        DispatchQueue.main.async { [weak self] in
            self?.onFinish()
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
        if let observer = itemDidPlayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        player?.pause()
    }
}

// MARK: - Reusable Interaction-Triggered Graphic SwiftUI Component

public struct InteractionAnimatedGraphicView: View {
    public let videoName: String?
    public let staticImageName: String?
    public let isTriggered: Bool
    public let blendMode: BlendMode
    public let videoGravity: AVLayerVideoGravity
    public let maxDuration: Double
    public let onFinish: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        videoName: String? = "backgroundleaf",
        staticImageName: String? = nil,
        isTriggered: Bool = false,
        blendMode: BlendMode = .multiply,
        videoGravity: AVLayerVideoGravity = .resizeAspect,
        maxDuration: Double = 1.8,
        onFinish: @escaping () -> Void = {}
    ) {
        self.videoName = videoName
        self.staticImageName = staticImageName
        self.isTriggered = isTriggered
        self.blendMode = blendMode
        self.videoGravity = videoGravity
        self.maxDuration = maxDuration
        self.onFinish = onFinish
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Static Base Graphic (Fallback / First Frame Match)
            if let imgName = staticImageName, !imgName.isEmpty {
                if videoGravity == .resizeAspectFill {
                    Image(imgName)
                        .resizable()
                        .scaledToFill()
                        .blendMode(blendMode)
                } else {
                    Image(imgName)
                        .resizable()
                        .scaledToFit()
                        .blendMode(blendMode)
                }
            }
            
            // Video Layer (if available)
            if let vName = videoName, !vName.isEmpty {
                InteractionVideoPlayerView(
                    videoName: vName,
                    videoGravity: videoGravity,
                    isTriggered: isTriggered && !reduceMotion,
                    maxDuration: maxDuration,
                    onFinish: onFinish
                )
                .blendMode(blendMode)
            }
        }
        .onChange(of: isTriggered) { triggered in
            if triggered && reduceMotion {
                // If user prefers reduced motion, skip video animation and transition immediately
                onFinish()
            }
        }
    }
}
