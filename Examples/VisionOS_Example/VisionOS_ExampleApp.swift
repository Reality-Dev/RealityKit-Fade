//
//  VisionOS_ExampleApp.swift
//  VisionOS_Example
//
//  Created by Grant Jarvis on 8/28/24.
//

import SwiftUI

@main
struct VisionOS_ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)
    }
}
