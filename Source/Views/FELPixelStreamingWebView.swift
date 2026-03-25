import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

/// Universal Launch: optional Pixel Streaming (Web) viewport when embedded Unreal handshake fails on lower-end hardware.
#if canImport(UIKit) && (!os(macOS) || targetEnvironment(macCatalyst))
struct FELPixelStreamingWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView()
        v.allowsBackForwardNavigationGestures = true
        v.load(URLRequest(url: url))
        return v
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url?.absoluteString != url.absoluteString {
            uiView.load(URLRequest(url: url))
        }
    }
}
#elseif os(macOS)
struct FELPixelStreamingWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let v = WKWebView()
        v.load(URLRequest(url: url))
        return v
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url?.absoluteString != url.absoluteString {
            nsView.load(URLRequest(url: url))
        }
    }
}
#endif
