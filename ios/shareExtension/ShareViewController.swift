class ShareViewController: RSIShareViewController {

    // Return false so we hand control back to the app rather than auto-redirect.
    override func shouldAutoRedirect() -> Bool {
        return false
    }
    
}
