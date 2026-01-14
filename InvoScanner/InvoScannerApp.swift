//
//  InvoScannerApp.swift
//  InvoScanner
//
//  Created by Bilal Elmas on 21.12.2025.
//

import SwiftUI
import SwiftData

@main
struct InvoScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // SwiftData: Fatura verilerini kalıcı olarak saklamak için model container
        .modelContainer(for: SavedInvoice.self)
    }
}
