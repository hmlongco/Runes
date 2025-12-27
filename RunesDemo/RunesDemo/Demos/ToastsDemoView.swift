//
//  ToastsDemoView.swift
//  RunesDemo
//
//  Created by Michael Long on 11/1/25.
//

import Combine
import Observation
import Runes
import SwiftUI

enum MyToasts: ToastViews {
    case message(String)
    case error(String)
    var body: some View {
        switch self {
        case .message(let message):
            Toast(message)
        case .error(let error):
            Toast(error: error)
        }
    }
}

struct ToastsDemoView: View {
    @Environment(\.toasts) var toasts
    @Environment(\.blocking) var blocking

    @State private var isBlocking = false
    @State private var toast: MyToasts?

    init() {
        Toast.defaultForegroundColor = .black
        Toast.defaultBackgroundColor = .green
    }

    var body: some View {
        List {
            Section {
                Button("Trigger Programatic Toasts") {
                    toasts.toast("A toast", icon: "info.circle.fill")
                    toasts.toast("Another toast", icon: "info.circle.fill")
                }
                Button("Trigger Message Toast Binding") {
                    toast = .message("This was a bound toast message.")
                }
            }
            Section {
                Button("Trigger Programatic Error") {
                    toasts.toast(error: "This is an error message.")
                }
                Button("Trigger Toast Error Binding") {
                    toast = .error("This is an error message.")
                }
            }
            Section {
                Button("Toggle Blocking (Timeout)") {
                    isBlocking = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isBlocking = false
                        toasts.toast(error: "Loading error")
                    }
                }
            }
        }
        .navigationTitle("Toasts Demo")
        .toast($toast)
        .blocking(isBlocking)
        .tint(.primary)
    }
}

#Preview {
    ContentView()
}
