import UIKit
import Social
import receive_sharing_intent

// Inherit from RSIShareViewController provided by receive_sharing_intent package
// This automatically handles:
// 1. Saving shared data to App Group storage
// 2. Opening the main app automatically
// 3. Providing data to Flutter via ReceiveSharingIntent.getInitialMedia()
class ShareViewController: RSIShareViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[SHARE EXTENSION] viewDidLoad called - using RSIShareViewController")
    }

    // Return true to automatically open the main app after sharing
    override func isContentValid() -> Bool {
        print("[SHARE EXTENSION] isContentValid called")
        return true
    }

    // Return true to automatically redirect to host app
    // This makes the Share Extension open the main app after processing
    override func shouldAutoRedirect() -> Bool {
        print("[SHARE EXTENSION] shouldAutoRedirect called - returning true for auto-launch")
        return true
    }
}
