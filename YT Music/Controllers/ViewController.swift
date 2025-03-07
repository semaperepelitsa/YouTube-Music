//
//  ViewController.swift
//  YT Music
//
//  Created by Stephen Radford on 19/06/2018.
//  Copyright © 2018 Cocoon Development Ltd. All rights reserved.
//

import Cocoa
import WebKit
import MediaKeyTap
import Magnet

class ViewController: NSViewController {

    var webView: CustomWebView!
    var userContentController: WKUserContentController!
    var standardButtonsView: NSView!
    var movableView: WindowMovableView!
    var mediaKeyTap: MediaKeyTap?
    var backButton: NSButton!
    var forwardButton: NSButton!
    var backObservation: NSKeyValueObservation?
    var forwardObservation: NSKeyValueObservation?
    var keyboardShortcuts: [KeyboardShortcut: HotKey] = [:]
    
    let navOffsetY : CGFloat = 16
    let titlebarHeight : CGFloat = 64
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.alphaValue = 0
        
        let url = URL(string: "https://music.youtube.com")!
        let request = URLRequest(url: url)
        webView.load(request)
        
        initializeKeyboardShortcuts()
        registerRemoteCommands()
        addObservers()
    }
    
    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        
        userContentController = WKUserContentController()
        userContentController.add(MediaCenter.default, name: "observer")
        webConfiguration.userContentController = userContentController

        let blockRules = """
            [{
                "trigger": {
                    "url-filter": "sw.js"
                },
                "action": {
                    "type": "block"
                }
            }]
         """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ContentBlockingRules",
            encodedContentRuleList: blockRules) { (contentRuleList, _) in
                webConfiguration.userContentController.add(contentRuleList!)
        }

        webView = CustomWebView(frame: .zero, configuration: webConfiguration)
        webView.wantsLayer = true
        webView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        webView.frame = NSRect(x: 0, y: 0, width: 1024, height: 768)
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.1.1 Safari/605.1.15"
        
        addStandardButtonsView()
        addMovableView()
        addNavigationButtons()
        
        view = webView
    }
    
    override func viewDidLayout() {
        
        super.viewDidLayout()
        
        if let btn = view.window?.standardWindowButton(.closeButton) {
            btn.removeFromSuperview()
            standardButtonsView.addSubview(btn)
        }

        if let btn = view.window?.standardWindowButton(.miniaturizeButton) {
            btn.removeFromSuperview()
            standardButtonsView.addSubview(btn)
        }

        if let btn = view.window?.standardWindowButton(.zoomButton) {
            btn.removeFromSuperview()
            standardButtonsView.addSubview(btn)
        }
        
        movableView.frame = CGRect(x: 0, y: webView.isFlipped ? 0 : webView.frame.height - titlebarHeight, width: webView.frame.width, height: titlebarHeight)
        
        let y = webView.isFlipped ? navOffsetY : webView.frame.height - 32 - navOffsetY
        
        var frame = backButton.frame
        frame.origin = CGPoint(x: 90, y: y)
        backButton.frame = frame
        
        frame = forwardButton.frame
        frame.origin = CGPoint(x: 130, y: y)
        forwardButton.frame = frame
        
    }
    
    func initializeKeyboardShortcuts() {
        if let keyCombo = KeyCombo(key: .space, cocoaModifiers: [.command, .shift]) {
            keyboardShortcuts[.playPause] = HotKey(identifier: "space", keyCombo: keyCombo) { hotKey in
                self.playPause()
            }
        }
        if let keyCombo = KeyCombo(key: .pageUp, cocoaModifiers: [.command, .shift]) {
            keyboardShortcuts[.next] = HotKey(identifier: "pageup", keyCombo: keyCombo) { hotKey in
                self.nextTrack()
            }
        }
        if let keyCombo = KeyCombo(key: .pageDown, cocoaModifiers: [.command, .shift]) {
            keyboardShortcuts[.previous] = HotKey(identifier: "pagedown", keyCombo: keyCombo) { hotKey in
                self.previousTrack();
            }
        }
    }
    
    func addObservers() {
        backObservation = webView.observe(\CustomWebView.canGoBack) { (webView, _) in
            self.backButton.isEnabled = webView.canGoBack
            self.backButton.image = webView.canGoBack ? #imageLiteral(resourceName: "Back Arrow Active") : #imageLiteral(resourceName: "Back Arrow Inactive")
        }
        
        forwardObservation = webView.observe(\CustomWebView.canGoForward) { (webView, _) in
            self.forwardButton.isEnabled = webView.canGoForward
            self.forwardButton.image = webView.canGoForward ? #imageLiteral(resourceName: "Forward Arrow Active") : #imageLiteral(resourceName: "Forward Arrow Inactive")
        }
    
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: NSNotification.Name.PreferencesChanged, object: nil)
    }
    
    @objc func preferencesChanged(notification: NSNotification) {
        refreshHotkeys()
    }
    
    func addNavigationButtons() {
        
        backButton = NSButton()
        backButton.image = #imageLiteral(resourceName: "Back Arrow Inactive")
        backButton.target = self
        backButton.action = #selector(backButtonClicked(_:))
        backButton.isEnabled = false
        backButton.bezelStyle = .shadowlessSquare
        backButton.isBordered = false
        
        let y = webView.isFlipped ? navOffsetY : webView.frame.height - 32 - navOffsetY
        
        backButton.frame = CGRect(x: 90, y: y, width: 32, height: 32)
        
        webView.addSubview(backButton)
        
        forwardButton = NSButton()
        forwardButton.image = #imageLiteral(resourceName: "Forward Arrow Inactive")
        forwardButton.target = self
        forwardButton.action = #selector(forwardButtonClicked(_:))
        forwardButton.isEnabled = false
        forwardButton.bezelStyle = .shadowlessSquare
        forwardButton.isBordered = false
        
        forwardButton.frame = CGRect(x: 130, y: y, width: 32, height: 32)
        
        webView.addSubview(forwardButton)
    }
    
    @objc func backButtonClicked(_ sender: NSButton) {
        webView.goBack()
    }
    
    @objc func forwardButtonClicked(_ sender: NSButton) {
        webView.goForward()
    }

    func addStandardButtonsView() {
        standardButtonsView = NSView(frame: CGRect(x: 14, y: 0, width: 80, height: 29 + navOffsetY))
        webView.addSubview(standardButtonsView)
    }
    
    func addMovableView() {
        movableView = WindowMovableView(frame: CGRect(x: 0, y: 0, width: webView.frame.width, height: titlebarHeight))
        webView.addSubview(movableView)
    }
    
    // MARK: - NSTouchBarProvider
    
    @available(macOS 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        return TouchBarController.shared.makeTouchBar()
    }
    
}

// MARK: - Delegates

extension ViewController: WKNavigationDelegate, WKUIDelegate {
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(error)
        print(navigation as Any)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url?.host == "music.youtube.com" else {
            view.animator().alphaValue = 1
            return
        }
        
        injectCustomCSS()
        injectCustomJS()
        view.animator().alphaValue = 1
    }
    
    func injectCustomCSS() {
        guard let cssURL = Bundle.main.url(forResource: "custom", withExtension: "css"),
        let css = try? String(contentsOf: cssURL) else {
            return
        }
        
        var js = "var style = document.createElement('style'); style.innerHTML = '\(css)'; document.head.appendChild(style);"
        js = js.replacingOccurrences(of: "\n", with: "")
        js = js.replacingOccurrences(of: "{", with: "\\{")
        js = js.replacingOccurrences(of: "}", with: "\\}")
        
        webView.evaluateJavaScript(js) { (_, error) in
            if let error = error {
                print(error)
            }
        }
    }
    
    /// Injects observers that the WKScriptMessageHandler will hear back from.
    /// These are used to detect when a track is playing etc.
    /// Also unregister any service workers that youtube music has registered.
    func injectCustomJS() {
        guard let jsURL = Bundle.main.url(forResource: "custom", withExtension: "js"),
        let js = try? String(contentsOf: jsURL) else {
            return
        }
        
        webView.evaluateJavaScript(js) { (_, error) in
            if let error = error {
                print(error)
            }
        }
    }
}
