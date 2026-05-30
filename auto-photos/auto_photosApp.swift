import AppTrackingTransparency
import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct auto_photosApp: App {
    init() {
        AppFontCatalog.registerBundledFonts()
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await requestTrackingIfNeeded() }
        }
    }

    private func requestTrackingIfNeeded() async {
        // Must be called after the first frame is rendered.
        try? await Task.sleep(nanoseconds: 500_000_000)
        await ATTrackingManager.requestTrackingAuthorization()
    }
}
