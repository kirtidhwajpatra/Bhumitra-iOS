import Foundation
import Combine
import GoogleMobileAds
import UIKit
import AppTrackingTransparency

class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdManager()
    
#if DEBUG
    // Testing Rewarded Ad Unit ID (guarantees 100% fill rate for local testing)
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712480198"
#else
    // Production Rewarded Ad Unit ID
    private let rewardedAdUnitID = "ca-app-pub-6825397802928097/8157771432"
#endif
    
    @Published var isAdLoaded = false
    
    private var rewardedAd: RewardedAd?
    private var onAdDismissed: (() -> Void)?
    
    override private init() {
        super.init()
    }
    
    func requestTrackingAuthorization() {
        if #available(iOS 14.5, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("App Tracking Status: \(status.rawValue)")
            }
        }
    }
    
    // Call this inside App's init
    func initialize() {
        MobileAds.shared.start { [weak self] _ in
            self?.loadRewardedAd()
        }
    }
    
    func loadRewardedAd() {
        let request = Request()
        RewardedAd.load(with: rewardedAdUnitID,
                        request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded ad with error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isAdLoaded = false
                }
                return
            }
            
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            
            DispatchQueue.main.async {
                self?.isAdLoaded = true
            }
            print("Rewarded ad loaded successfully")
        }
    }
    
    func showAd(completion: @escaping () -> Void) {
        // Ads temporarily disabled
        completion()
    }
    
    // MARK: - FullScreenContentDelegate
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("Ad recorded impression.")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("Ad recorded click.")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present full screen content with error: \(error.localizedDescription).")
        DispatchQueue.main.async { [weak self] in
            self?.onAdDismissed?()
            self?.onAdDismissed = nil
            self?.loadRewardedAd()
        }
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad will present full screen content.")
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad will dismiss full screen content.")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad did dismiss full screen content.")
        DispatchQueue.main.async { [weak self] in
            self?.onAdDismissed?()
            self?.onAdDismissed = nil
            self?.loadRewardedAd()
        }
    }
    
    // Helper to get the top view controller
    private func getRootViewController() -> UIViewController? {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        guard let root = screen.windows.first?.rootViewController else {
            return nil
        }
        
        var currentController = root
        while let presentedController = currentController.presentedViewController {
            currentController = presentedController
        }
        return currentController
    }
}
