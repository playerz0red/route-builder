//
//  ContentView.swift
//  RouteBuilder
//
//  Temporary connectivity check; removed in Task 19.
//

import SwiftUI
import RouteAPI

struct ContentView: View {
    @State private var message = "Loading..."

    var body: some View {
        Text(message)
            .font(.system(.body, design: .monospaced))
            .padding()
            .task { await check() }
    }

    @MainActor
    private func check() async {
        let value = Bundle.main.object(forInfoDictionaryKey: APIConfiguration.infoPlistKey)
        guard let base = APIConfiguration.baseURL(fromInfoValue: value) else {
            message = "API base URL is not configured"
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: base.appendingPathComponent("health"))
            message = String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"
        } catch let error as URLError {
            message = "URLError \(error.code.rawValue)"
        } catch {
            message = "\(error)"
        }
    }
}

#Preview {
    ContentView()
}
