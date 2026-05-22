import SwiftUI
//
//  ContentView.swift
//  Untilt
//
//  Created by Abraham Rubin on 5/11/26.
//


struct ContentView: View {
    @State private var showHomeView = false
    
    var body: some View {
        if showHomeView {
            HomeView()
        } else {
            BoxBreathingView {
                showHomeView = true
            }
        }
    }
}

#Preview {
    ContentView()
}

