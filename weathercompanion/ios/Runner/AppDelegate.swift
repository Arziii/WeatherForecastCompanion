import Flutter
import UIKit
import AVFoundation // <--- ADD THIS LINE
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ADD THIS BLOCK OF CODE
    if #available(iOS 10.0, *) {
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
    }
    // --- END OF BLOCK ---
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
