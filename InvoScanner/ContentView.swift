import SwiftUI

/// Ana içerik görünümü
/// - TabView ile Dashboard, Liste, Tarama ve Demo arasında geçiş
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie")
                }
                .tag(0)
            
            InvoiceListView()
                .tabItem {
                    Label("Faturalar", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
            
            ScannerView()
                .tabItem {
                    Label("Tarama", systemImage: "doc.viewfinder")
                }
                .tag(2)
            
            DemoView()
                .tabItem {
                    Label("Demo Test", systemImage: "testtube.2")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
