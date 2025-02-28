//
//  Copyright 2015 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import GoogleMobileAds
import UIKit

class ViewController: UIViewController {

  /// The privacy settings button.
  @IBOutlet weak var privacySettingsButton: UIBarButtonItem!

  /// The ad inspector button.
  @IBOutlet weak var adInspectorButton: UIBarButtonItem!

  /// The view that holds the native ad.
  @IBOutlet weak var nativeAdPlaceholder: UIView!

  /// Displays status messages about presence of video assets.
  @IBOutlet weak var videoStatusLabel: UILabel!

  /// The app install ad switch.
  @IBOutlet weak var nativeAdSwitch: UISwitch!

  /// The custom native ad switch.
  @IBOutlet weak var customNativeAdSwitch: UISwitch!

  /// The refresh ad button.
  @IBOutlet weak var refreshAdButton: UIButton!

  /// The SDK version label.
  @IBOutlet weak var versionLabel: UILabel!

  /// Switch to indicate if video ads should start muted.
  @IBOutlet weak var startMutedSwitch: UISwitch!

  /// The ad loader. You must keep a strong reference to the GADAdLoader during the ad loading
  /// process.
  var adLoader: AdLoader!

  /// The native ad view that is being presented.
  var nativeAdView: UIView!

  /// Indicates whether the Google Mobile Ads SDK has started.
  private var isMobileAdsStartCalled = false

  /// The ad unit ID.
  let adUnitID = "/3865/ddm.people.app/feed/app-flex-1"

  /// The native custom format id
  let nativeCustomFormatId = "12416731"
    /// The ad unit ID.
//      let adUnitID = "/21775744923/example/native"
//
//      /// The native custom format id
//      let nativeCustomFormatId = "12387226"

  /// Handle changes to user consent.
  @IBAction func privacySettingsTapped(_ sender: UIBarButtonItem) {
    Task {
      do {
        try await GoogleMobileAdsConsentManager.shared.presentPrivacyOptionsForm(from: self)
      } catch {
        let alertController = UIAlertController(
          title: error.localizedDescription, message: "Please try again later.",
          preferredStyle: .alert)
        alertController.addAction(
          UIAlertAction(
            title: "OK", style: .cancel,
            handler: nil))
        present(alertController, animated: true)
      }
    }
  }

  /// Handle ad inspector launch.
  @IBAction func adInspectorTapped(_ sender: UIBarButtonItem) {
    Task {
      do {
        try await MobileAds.shared.presentAdInspector(from: self)
      } catch {
        let alertController = UIAlertController(
          title: error.localizedDescription, message: "Please try again later.",
          preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alertController, animated: true)
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    versionLabel.text = string(for: MobileAds.shared.versionNumber)

    GoogleMobileAdsConsentManager.shared.gatherConsent(from: self) { [weak self] consentError in
      guard let self else { return }

      if let consentError {
        // Consent gathering failed.
        print("Error: \(consentError.localizedDescription)")
      }

      if GoogleMobileAdsConsentManager.shared.canRequestAds {
        self.startGoogleMobileAdsSDK()
      }

      self.refreshAdButton.isHidden = !GoogleMobileAdsConsentManager.shared.canRequestAds

      self.privacySettingsButton.isEnabled =
        GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired
    }

    // This sample attempts to load ads using consent obtained in the previous session.
    if GoogleMobileAdsConsentManager.shared.canRequestAds {
      startGoogleMobileAdsSDK()
    }
  }

  private func startGoogleMobileAdsSDK() {
    DispatchQueue.main.async {
      guard !self.isMobileAdsStartCalled else { return }

      self.isMobileAdsStartCalled = true

      // Initialize the Google Mobile Ads SDK.
      MobileAds.shared.start()
      // Request an ad.
      self.refreshAd(nil)
    }
  }

  func setAdView(_ view: UIView) {
    nativeAdView?.removeFromSuperview()
    nativeAdView = view
    nativeAdPlaceholder.addSubview(nativeAdView)
    nativeAdView.translatesAutoresizingMaskIntoConstraints = false

    // Layout constraints for positioning the native ad view to stretch the entire width and height
    // of the nativeAdPlaceholder.
    NSLayoutConstraint.activate([
      nativeAdView.leadingAnchor.constraint(equalTo: nativeAdPlaceholder.leadingAnchor),
      nativeAdView.trailingAnchor.constraint(equalTo: nativeAdPlaceholder.trailingAnchor),
      nativeAdView.topAnchor.constraint(equalTo: nativeAdPlaceholder.topAnchor),
      nativeAdView.bottomAnchor.constraint(equalTo: nativeAdPlaceholder.bottomAnchor),
    ])
  }

  // MARK: - Actions

  /// Refreshes the native ad.
  @IBAction func refreshAd(_ sender: AnyObject!) {
    var adTypes = [AdLoaderAdType]()
    if nativeAdSwitch.isOn {
      adTypes.append(.native)
    }
    if customNativeAdSwitch.isOn {
      adTypes.append(.customNative)
    }

    if adTypes.isEmpty {
      let alert = UIAlertController(
        title: "Alert",
        message: "At least one ad format must be selected to refresh the ad.",
        preferredStyle: .alert)
      let alertAction = UIAlertAction(
        title: "OK",
        style: .cancel,
        handler: nil)
      alert.addAction(alertAction)
      self.present(alert, animated: true, completion: nil)
    } else {
      refreshAdButton.isEnabled = false
      let videoOptions = VideoOptions()
      videoOptions.shouldStartMuted = startMutedSwitch.isOn
      adLoader = AdLoader(
        adUnitID: adUnitID, rootViewController: self,
        adTypes: adTypes, options: [videoOptions])
      adLoader.delegate = self
      
      let request = Request()
      
      // Add custom targeting
      request.customTargeting = [
          "advertest": "moonshotvideo"
      ]
      
      adLoader.load(request)
      videoStatusLabel.text = ""
    }
  }

  /// Returns a `UIImage` representing the number of stars from the given star rating; returns `nil`
  /// if the star rating is less than 3.5 stars.
  func imageOfStars(fromStarRating starRating: NSDecimalNumber?) -> UIImage? {
    guard let rating = starRating?.doubleValue else {
      return nil
    }
    if rating >= 5 {
      return UIImage(named: "stars_5")
    } else if rating >= 4.5 {
      return UIImage(named: "stars_4_5")
    } else if rating >= 4 {
      return UIImage(named: "stars_4")
    } else if rating >= 3.5 {
      return UIImage(named: "stars_3_5")
    } else {
      return nil
    }
  }

  /// Updates the videoController's delegate and viewController's UI according to videoController
  /// 'hasVideoContent()' value.
  /// Some content ads will include a video asset, while others do not. Apps can use the
  /// GADVideoController's hasVideoContent property to determine if one is present, and adjust their
  /// UI accordingly.
  func updateVideoStatusLabel(hasVideoContent: Bool) {
    if hasVideoContent {
      // By acting as the delegate to the GADVideoController, this ViewController receives messages
      // about events in the video lifecycle.
      videoStatusLabel.text = "Ad contains a video asset."
    } else {
      videoStatusLabel.text = "Ad does not contain a video."
    }
  }

}

// MARK: - GADAdLoaderDelegate

extension ViewController: @preconcurrency AdLoaderDelegate {

  func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
    print("\(adLoader) failed with error: \(error.localizedDescription)")
    refreshAdButton.isEnabled = true
  }
}

// MARK: - GADNativeAdLoaderDelegate

extension ViewController: @preconcurrency NativeAdLoaderDelegate {

  func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
    print("Received native ad: \(nativeAd)")
    refreshAdButton.isEnabled = true
    
    // Create and place ad in view hierarchy.
    let nibView = Bundle.main.loadNibNamed("NativeAdView", owner: nil, options: nil)?.first
    guard let nativeAdView = nibView as? NativeAdView else {
      return
    }
    setAdView(nativeAdView)

    // Set ourselves as the native ad delegate to be notified of native ad events.
    nativeAd.delegate = self

    // Populate the native ad view with the native ad assets.
    // The headline and mediaContent are guaranteed to be present in every native ad.
    (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
    nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

    // Some native ads will include a video asset, while others do not. Apps can use the
    // GADVideoController's hasVideoContent property to determine if one is present, and adjust their
    // UI accordingly.
    // Update the ViewController for video content.
      
    let hasVideoContent = nativeAd.mediaContent.hasVideoContent
    updateVideoStatusLabel(hasVideoContent: hasVideoContent)
    if hasVideoContent {
      // By acting as the delegate to the GADVideoController, this ViewController receives messages
      // about events in the video lifecycle.
      nativeAd.mediaContent.videoController.delegate = self
    }

    // This app uses a fixed width for the GADMediaView and changes its height to match the aspect
    // ratio of the media it displays.
    if let mediaView = nativeAdView.mediaView, nativeAd.mediaContent.aspectRatio > 0 {
      let aspectRatioConstraint = NSLayoutConstraint(
        item: mediaView,
        attribute: .width,
        relatedBy: .equal,
        toItem: mediaView,
        attribute: .height,
        multiplier: CGFloat(nativeAd.mediaContent.aspectRatio),
        constant: 0)
      mediaView.addConstraint(aspectRatioConstraint)
      nativeAdView.layoutIfNeeded()
    }

    // These assets are not guaranteed to be present. Check that they are before
    // showing or hiding them.
    (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
    nativeAdView.bodyView?.isHidden = nativeAd.body == nil

    (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
    nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

    (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
    nativeAdView.iconView?.isHidden = nativeAd.icon == nil

    (nativeAdView.starRatingView as? UIImageView)?.image = imageOfStars(
      fromStarRating: nativeAd.starRating)
    nativeAdView.starRatingView?.isHidden = nativeAd.starRating == nil

    (nativeAdView.storeView as? UILabel)?.text = nativeAd.store
    nativeAdView.storeView?.isHidden = nativeAd.store == nil

    (nativeAdView.priceView as? UILabel)?.text = nativeAd.price
    nativeAdView.priceView?.isHidden = nativeAd.price == nil

    (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
    nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

    // In order for the SDK to process touch events properly, user interaction should be disabled.
    nativeAdView.callToActionView?.isUserInteractionEnabled = false

    // Associate the native ad view with the native ad object. This is
    // required to make the ad clickable.
    // Note: this should always be done after populating the ad views.
    nativeAdView.nativeAd = nativeAd
  }
}

// MARK: - GADCustomNativeAdLoaderDelegate

extension ViewController: @preconcurrency CustomNativeAdLoaderDelegate {
  func customNativeAdFormatIDs(for adLoader: AdLoader) -> [String] {
    return [nativeCustomFormatId]
  }

  func adLoader(
    _ adLoader: AdLoader,
    didReceive customNativeAd: CustomNativeAd
  ) {
    print("Received custom native ad: \(customNativeAd)")
      print("Available asset keys:", customNativeAd.availableAssetKeys)
      for key in customNativeAd.availableAssetKeys {
          if let value = customNativeAd.string(forKey: key) {
              print("Key: \(key), Value: \(value)")
          }
      }
      if let videoURLString = customNativeAd.string(forKey: "Video") {
          print("Video URL: \(videoURLString)")
          
          // Convert the string to a valid URL
          if let videoURL = URL(string: videoURLString) {
              let tempDirectory = FileManager.default.temporaryDirectory
              let tempURL = tempDirectory.appendingPathComponent("ad_video.mp4")

              do {
                  try videoURL.absoluteString.write(to: tempURL, atomically: true, encoding: .utf8)
                  print("Temporary Video URL: \(tempURL.absoluteString)")
              } catch {
                  print("Failed to write video URL to temp directory:", error)
              }
          }
      } else {
          print("No direct video URL found in the custom native ad.")
      }
      

      if let imageAsset = customNativeAd.image(forKey: "image")?.image,
         let pngData = imageAsset.pngData() {
          
          let tempDirectory = FileManager.default.temporaryDirectory
          let tempURL = tempDirectory.appendingPathComponent("ad_image.png")
          
          do {
              try pngData.write(to: tempURL)
              print("Temporary Image URL: \(tempURL.absoluteString)")
          } catch {
              print("Failed to write to temp directory:", error)
          }
      }
    refreshAdButton.isEnabled = true

    // Log regular string assets
    for assetKey in customNativeAd.availableAssetKeys {
        if assetKey != "_videoMediaView" {
            if let value = customNativeAd.string(forKey: assetKey) {
                print("Asset: \(assetKey) = \(value)")
            }
        }
    }
    
    let responseInfo = customNativeAd.responseInfo
    print("Full Response Info: \(responseInfo)")

    // Create and place the ad in the view hierarchy.
    let customNativeAdView =
      Bundle.main.loadNibNamed(
        "SimpleCustomNativeAdView", owner: nil, options: nil)!.first as! MySimpleNativeAdView
    setAdView(customNativeAdView)

    let hasVideoContent = customNativeAd.mediaContent.hasVideoContent
    // Update the ViewController for video content.
    updateVideoStatusLabel(hasVideoContent: hasVideoContent)
    if hasVideoContent {
      customNativeAd.mediaContent.videoController.delegate = self
    }
    // Populate the custom native ad view with the custom native ad assets.
    customNativeAdView.populate(withCustomNativeAd: customNativeAd)
    // Impressions for custom native ads must be manually tracked. If this is not called,
    // videos will also not be played.
    customNativeAd.recordImpression()
  }
}

// MARK: - GADVideoControllerDelegate implementation
extension ViewController: @preconcurrency VideoControllerDelegate {

  func videoControllerDidEndVideoPlayback(_ videoController: VideoController) {
    videoStatusLabel.text = "Video playback has ended."
  }
}

// MARK: - GADNativeAdDelegate implementation
extension ViewController: @preconcurrency NativeAdDelegate {

  func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

  func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

  func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

  func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

  func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }

  func nativeAdWillLeaveApplication(_ nativeAd: NativeAd) {
    print("\(#function) called")
  }
}
