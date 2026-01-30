//
//  forksApp.swift
//  forks
//
//  Created by Fuxian on 2026/1/24.
//

import SwiftUI

@main
struct forksApp: App {
    @State private var showNpxAlert = false
    @State private var npxCheckComplete = false
    @StateObject private var updateService = UpdateService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    checkForNpx()
                }
                .alert("Node.js Required", isPresented: $showNpxAlert) {
                    Button("Open nodejs.org") {
                        if let url = URL(string: "https://nodejs.org") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Install via Homebrew") {
                        if let url = URL(string: "https://brew.sh") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Continue Anyway", role: .cancel) {}
                } message: {
                    Text("This app requires Node.js (npx) to install skills. Please install Node.js to use all features.\n\nInstall options:\n• Download from nodejs.org\n• Run: brew install node")
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateService.checkForUpdates()
                }
            }
        }
    }
    
    private func checkForNpx() {
        guard !npxCheckComplete else { return }
        npxCheckComplete = true
        
        let paths = [
            "/usr/local/bin/npx",
            "/opt/homebrew/bin/npx",
            "/usr/bin/npx"
        ]
        
        let npxExists = paths.contains { path in
            FileManager.default.fileExists(atPath: path)
        }
        
        if !npxExists {
            // Also try 'which npx' as fallback
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            task.arguments = ["npx"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus != 0 {
                    showNpxAlert = true
                }
            } catch {
                showNpxAlert = true
            }
        }
    }
}
