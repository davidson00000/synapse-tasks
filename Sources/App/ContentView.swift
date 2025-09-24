import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Synapse Tasks")
                .font(.system(size: 28, weight: .bold))
            Text("IDEゼロ運用：XcodeGen + xcodebuild")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
