//
//  UpdateService.swift
//  forks
//
//  Created by Adapter on 2024/01/30.
//

import Foundation
import Sparkle
import SwiftUI
import Combine

class UpdateService: NSObject, ObservableObject {
    // SPUStandardUpdaterController must be held strongly to keep the updater alive.
    private let updaterController: SPUStandardUpdaterController
    
    // Add a published property to force ObservableObject synthesis and allow UI updates if needed
    @Published var lastCheckTime: Date?

    override init() {
        // Initialize the updater controller.
        // startingUpdater: true ensures the updater lifecycle usually starts automatically.
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    /// Action to trigger a user-initiated update check
    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }
}
