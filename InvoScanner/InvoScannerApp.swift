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
    
    init() {
        // TabBar için cam efekti (Liquid Glass)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        
        // NavigationBar görünümü
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Liquid Glass için karanlık mod zorunlu
        }
        // SwiftData: Fatura verilerini kalıcı olarak saklamak için model container
        .modelContainer(for: SavedInvoice.self)
    }
}
