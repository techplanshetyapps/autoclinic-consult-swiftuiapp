//
//  HomeContactView.swift
//  AutoClinicConsult
//
//  Home / Connect circles, same pattern as the reference app.
//

import SwiftUI

struct HomeContactView: View {
    @State private var showConnectSheet = false

    var body: some View {
        HStack(spacing: 16) {
            circle(systemImage: "house.fill") {}
            circle(systemImage: "link") { showConnectSheet = true }
        }
        .sheet(isPresented: $showConnectSheet) {
            ConnectSheet()
        }
    }

    private func circle(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.5), in: Circle())
        }
    }
}

private struct ConnectSheet: View {
    var body: some View {
        List {
            Link("LinkedIn", destination: URL(string: "https://www.linkedin.com/")!)
            Link("Vimeo demo", destination: URL(string: "https://vimeo.com/")!)
            Link("GitHub — autoclinic-consult-api", destination: URL(string: "https://github.com/")!)
        }
    }
}
