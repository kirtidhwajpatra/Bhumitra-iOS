import Foundation
import Combine
import GoogleMobileAds
import UIKit

class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdManager()
    
    // Testing Interstitial Ad Unit ID
    // Replace heavily with your actual real ad unit ID before releasing
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    
    @Published var isAdLoaded = false
    
    private var interstitialAd: InterstitialAd?
    private var onAdDismissed: (() -> Void)?
    
    override private init() {
        super.init()
    }
    
    // Call this inside App's init
    func initialize() {
        MobileAds.shared.start { [weak self] _ in
            self?.loadInterstitialAd()
        }
    }
    
    func loadInterstitialAd() {
        let request = Request()
        InterstitialAd.load(with: interstitialAdUnitID,
                            request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isAdLoaded = false
                }
                return
            }
            
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            
            DispatchQueue.main.async {
                self?.isAdLoaded = true
            }
            print("Interstitial ad loaded successfully")
        }
    }
    
    func showAd(completion: @escaping () -> Void) {
        // If ad is not ready, just call completion instantly
        guard let ad = interstitialAd, let rootVC = getRootViewController() else {
            print("Ad wasn't ready or root VC not found, skipping ad.")
            completion()
            loadInterstitialAd() // try loading next time
            return
        }
        
        self.onAdDismissed = completion
        ad.present(from: rootVC)
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
            self?.loadInterstitialAd()
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
            self?.loadInterstitialAd()
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
