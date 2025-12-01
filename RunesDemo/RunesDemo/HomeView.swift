//
//  HomeView.swift
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
            StandardTextToast(message: message)
        case .error(let error):
            StandardTextToast(error: error)
        }
    }
}

struct HomeView: View {
    @Environment(\.toasts) var toasts
    @Environment(\.blocking) var blocking

    @State private var isBlocking = false
    @State private var toast: MyToasts?

    init() {
        StandardTextToast.defaultForegroundColor = .black
        StandardTextToast.defaultBackgroundColor = .green
    }

    var body: some View {
        List {
            Section {
                Button("Trigger Programatic Toasts") {
                    toasts.show(message: "A toast")
                    toasts.show(message: "Another toast")
                }
                Button("Trigger Message Toast Binding") {
                    toast = .message("This was a bound toast message.")
                }
            }
            Section {
                Button("Trigger Programatic Error") {
                    toasts.show(error: "This is an error message.")
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
                        toasts.show(error: "Loading error")
                    }
                }
            }
        }
        .showToast($toast)
        .blocking(isPresented: isBlocking)
        .tint(.primary)
    }
}

#Preview {
    ContentView()
}
