import SwiftUI

struct ContentView: View {
    @State private var showDebugView = false
    
    var body: some View {
        NavigationStack {
            if showDebugView {
                WalletDebugView()
                    .navigationTitle("Wallet Debug")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Show Main UI") {
                                showDebugView = false
                            }
                        }
                    }
            } else {
                WalletView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Debug Mode") {
                                showDebugView = true
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
