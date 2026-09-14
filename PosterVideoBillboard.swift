//
//  PosterVideoBillboard.swift
//  AutoClinicConsult
//
//  Same pattern as the reference app: swaps a static poster for a muted,
//  looping WKWebView Vimeo background embed while the device is in motion,
//  and reverts to the poster at rest.
//

import SwiftUI
import WebKit

struct PosterVideoBillboard: View {
    let vimeoID: String
    let isMoving: Bool

    var body: some View {
        ZStack {
            if isMoving {
                VimeoBackgroundWebView(vimeoID: vimeoID)
                    .transition(.opacity)
            } else {
                Image("hospitalPoster")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isMoving)
        .clipped()
    }
}

private struct VimeoBackgroundWebView: UIViewRepresentable {
    let vimeoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        let urlString = "https://player.vimeo.com/video/\(vimeoID)?background=1&autoplay=1&loop=1&muted=1"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
