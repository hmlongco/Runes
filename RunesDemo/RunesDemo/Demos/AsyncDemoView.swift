//
//  ContentView.swift
//  AsyncTrials
//
//  Created by Michael Long on 12/18/25.
//

import Combine
import Observation
import Runes
import SwiftUI

struct AsyncDemoView: View {
    @State private var viewModel: AsyncDemoViewModel = .init()
    let index: Int
    var body: some View {
        List {
            NavigationLink(value: Destinations.async(index + 1)) {
                Text("Another Async Demo")
            }
            // some listeners
            Section {
                AsyncFunctionTaskValueView(viewModel: viewModel)
                TaskValueView(viewModel: viewModel)
                ThrowingTaskValueView(viewModel: viewModel)
                PublisherValueView(viewModel: viewModel)
            }
            if viewModel.another {
                TaskValueView(viewModel: viewModel)
            }
            // actions
            Section {
                Button("Show Another Value") {
                    viewModel.another = true
                }
                Button("Side Effect") {
                    viewModel.sideEffect()
                }
                Button("Reload") {
                    viewModel.reload()
                }
                Button("Cancel") {
                    viewModel.service.integers.cancel()
                }
            }
        }
        .navigationTitle("Async Demo \(index)")
    }
}

struct AsyncFunctionTaskValueView: View {
    let viewModel: AsyncDemoViewModel
    var body: some View {
        Text("Async Function Task Value: \(String(describing: viewModel.integer))")
            .task {
                print("Async Function Listening")
                await viewModel.asyncListen()
                print("Async Function Listening completed")
            }
            .task {
                print("Async Group Listening")
                await viewModel.asyncTaskGroupListen()
                print("Async Group Listening completed")
            }
    }
}

struct TaskValueView: View {
    @State private var value: Int? = nil
    let viewModel: AsyncDemoViewModel
    var body: some View {
        Text("Task Value: \(String(describing: value))")
            .task {
                for await next in viewModel.service.integers.stream {
                    print("Streamed: \(next)")
                    self.value = next.value
                }
                print("Streaming completed")
            }
    }
}

struct ThrowingTaskValueView: View {
    @State private var value: Int? = nil
    @State private var cancelled: Bool = false
    let viewModel: AsyncDemoViewModel
    var body: some View {
        Text("Throwing Task Value: \(cancelled ? "Cancelled" : String(describing: value))")
            .task {
                do {
                    for try await value in viewModel.service.integers.values {
                        print("Throwing task value: \(String(describing: value))")
                        self.value = value
                    }
                    print("Throwing task completed")
                } catch is CancellationError {
                    print("Throwing task cancelled")
                    cancelled = true
                } catch {
                    print("Throwing task error: \(error)")
                }
            }
    }
}

struct PublisherValueView: View {
    @State private var value: Int? = nil
    let viewModel: AsyncDemoViewModel
    var body: some View {
        Text("Published Value: \(String(describing: value))")
            .onReceive(viewModel.service.integers.publisher) { next in
                print("Received: \(next)")
                self.value = next.value
            }
    }
}

@MainActor
@Observable
class AsyncDemoViewModel {
    @ObservationIgnored
    let service = TestService()
    @ObservationIgnored
    var cancellables = Set<AnyCancellable>()

    var integer: Int? = nil
    var double: Double? = nil
    var another: Bool = false

    init() {
        taskListen()
    }

    func asyncListen() async {
        for await next in service.integers.stream {
            integer = next.value
        }
    }

    func asyncListen2() async {
        for await next in service.integers.stream {
            integer = next.value
        }
    }

    func asyncTaskGroupListen() async {
        await withTaskGroup { [service] group in
            group.addTask {
                for await next in service.integers.stream {
                    DispatchQueue.main.async { self.integer = next.value }
                }
                print("Exit asyncTaskGroupListen")
            }
            group.addTask {
                for await next in service.doubles.stream {
                    DispatchQueue.main.async { self.double = next.value }
                }
                print("Exit asyncTaskGroupListen")
            }
        }
    }

    func taskListen() {
        Task { [weak self, service] in
            for await next in service.integers.stream {
                self?.integer = next.value
            }
            print("Exit taskListen")
        }
        .store(in: &cancellables)
    }

    func sideEffect() {
        service.sideEffect()
    }

    func reload() {
        service.integers.reload()
    }

    deinit {
        print("AsyncDemoViewModel deinit")
    }
}

class TestService {
    private let networking = NetworkingService()
    private var cancellables = Set<AnyCancellable>()

    lazy var integers: SharedAsyncStream<Int> = .init(options: [.reloadOnActive]) { [weak self] in
        try await self?.networking.load()
    }

    lazy var doubles: SharedAsyncStream<Double> = .init(initialValue: 2.0)

    var integer: Int? = nil {
        didSet {
            print("Updated integer to \(String(describing: integer))")
        }
    }

    var element: SharedAsyncStream<Int>.Element = .loading {
        didSet {
            print("Updated element to \(String(describing: element))")
        }
    }

    init() {
        monitorViaTask()
        monitorViaPublisher()
        monitorViaAssignment()
        monitorViaObserver()
    }

    deinit {
        print("TestService deinit")
    }

    func monitorViaAssignment() {
        integers.assign(\.element, on: self)
        integers.assign(\.integer, on: self)
    }

    func monitorViaObserver() {
        integers.addObserver(self) { element in
            print("Observed \(element)")
        }
    }

    func monitorViaTask() {
        Task { [weak self, integers] in
            for await next in integers.stream {
                self?.lastValueSeen = next.value
            }
            print("Task monitoring completed")
        }
        .store(in: &cancellables)
    }

    func monitorViaPublisher() {
        integers.publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] next in
                self?.lastValueSeen = next.value
            }
            .store(in: &cancellables)
    }

    var lastValueSeen: Int? = nil

    func sideEffect() {
        integers.send(4)
        doubles.send(4.0)
    }
}

class NetworkingService {
    func load() async throws -> Int {
        try await Task.sleep(nanoseconds: 4_000_000_000)
        return 2
    }

    deinit {
        print("NetworkingService deinit")
    }
}

#Preview {
    ContentView()
}
