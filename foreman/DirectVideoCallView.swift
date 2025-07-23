//
//  DirectVideoCallView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/22.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct DirectVideoCallFeature {
    @ObservableState
    struct State: Equatable {
        var showConfig: Bool = false
        var distanceFt: Double = 10.0
        var batteryLevel: Int = 100
    }

    enum Action: TCAFeatureAction {
        @CasePathable
        enum ViewAction: Equatable {
            case onAppear
            case showConfig(Bool)
            case updateDistanceRandom
            case closeConfig
        }

        @CasePathable
        enum InternalAction: Equatable {
            case batteryLevelChanged(Int)
        }

        enum DelegateAction: Equatable {
            // For future delegate logic
        }

        case view(ViewAction)
        case _internal(InternalAction)
        case delegate(DelegateAction)
    }

    enum CancelID {
        case battery
    }

    @Dependency(\.batteryClient) var batteryClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear):
                // Start battery monitoring
                return .publisher {
                    batteryClient.batteryLevelPublisher()
                        .map { ._internal(.batteryLevelChanged($0)) }
                }
                .cancellable(id: CancelID.battery)
            case .view(.showConfig(let show)):
                state.showConfig = show
                return .none
            case .view(.updateDistanceRandom):
                state.distanceFt = Double.random(in: 1 ... 100)
                return .none
            case .view(.closeConfig):
                state.showConfig = false
                return .none
            case ._internal(.batteryLevelChanged(let value)):
                state.batteryLevel = value
                return .none
            case .delegate:
                return .none
            case ._internal:
                return .none
            }
        }
    }
}

struct DirectVideoCallView: View {
    let store: StoreOf<DirectVideoCallFeature>

    @Dependency(\.webRTCClient) var webRTCClientDependency

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack {
                // Main video call view (fills background)
                VideoCallView(webRTCClient: WebRTCClientLive.shared.getClient())

                cornerOverlay(position: .topLeading) {
                    Button(action: {
                        viewStore.send(.view(.showConfig(true)))
                    }) {
                        Image(systemName: "gearshape")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.blue)
                            .padding(8)
                    }
                    .sheet(isPresented: viewStore.binding(get: \ .showConfig, send: { .view(.showConfig($0)) })) {
                        ConfigPopupView(viewStore: viewStore)
                    }
                }
                cornerOverlay(position: .topTrailing) {
                    WifiSignalView()
                }
                cornerOverlay(position: .bottomLeading) {
                    RulerDistanceView(distance: viewStore.distanceFt) {
                        viewStore.send(.view(.updateDistanceRandom))
                    }
                }
                cornerOverlay(position: .bottomTrailing) {
                    BatteryIconView()
                }
            }
            .onAppear {
                viewStore.send(.view(.onAppear))
                print("🎥 DirectVideoCallView: Video viewer started with WebRTC client")
                let client = WebRTCClientLive.shared.getClient()
                print("🎥 DirectVideoCallView: Current video tracks count: \(client.remoteVideoTracks.count)")
                for (index, track) in client.remoteVideoTracks.enumerated() {
                    print("🎥 Track \(index): User \(track.userId), Enabled: \(track.track?.isEnabled ?? false)")
                }
            }
        }
    }

    @ViewBuilder
    func RulerDistanceView(distance: Double, onUpdate: @escaping () -> Void) -> some View {
        // Ruler parameters
        let minFt: Double = 0
        let maxFt: Double = 100
        let rulerWidth: CGFloat = 180
        let markerSize: CGFloat = 18

        VStack(spacing: 8) {
            Text("Distance")
                .font(.caption)
                .foregroundColor(.gray)
            ZStack(alignment: .leading) {
                // Ruler bar
                Rectangle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: rulerWidth, height: 8)
                    .cornerRadius(4)
                // Tick marks
                HStack(spacing: 0) {
                    ForEach(0 ..< 11) { i in
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: 2, height: i % 5 == 0 ? 16 : 10)
                        Spacer()
                    }
                }
                .frame(width: rulerWidth, height: 16)
                // Marker
                Circle()
                    .fill(Color.purple)
                    .frame(width: markerSize, height: markerSize)
                    .offset(x: CGFloat((distance - minFt) / (maxFt - minFt)) * (rulerWidth - markerSize))
                    .shadow(radius: 2)
                // Value label above marker
                Text(String(format: "%.1f ft", distance))
                    .font(.caption2)
                    .foregroundColor(.purple)
                    .offset(x: CGFloat((distance - minFt) / (maxFt - minFt)) * (rulerWidth - markerSize) - 10, y: -22)
            }
            .frame(width: rulerWidth, height: 32)
            Button(action: onUpdate) {
                Text("Update Distance")
                    .font(.caption2)
                    .padding(6)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    @ViewBuilder
    func ConfigPopupView(viewStore: ViewStoreOf<DirectVideoCallFeature>) -> some View {
        VStack(spacing: 20) {
            Text("Configuration")
                .font(.headline)
            Divider()
            Text("Settings go here.")
            Button("Close") {
                viewStore.send(.view(.closeConfig))
            }
            .padding()
        }
        .padding()
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    func cornerButton(label: String) -> some View {
        Button(action: {
            print("Button tapped at \(label)")
        }) {
            Text(label)
                .font(.caption)
                .padding(8)
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(8)
    }

    @ViewBuilder
    func WifiSignalView() -> some View {
        // Use SF Symbol for wifi icon and simulate signal strength
        VStack {
            Button(action: {
                print("Wifi icon tapped. Listening to wifi signal...")
            }) {
                Image(systemName: "wifi")
                    .resizable()
                    .frame(width: 28, height: 22)
                    .foregroundColor(.green)
            }
            Text("Signal: -- dBm")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(8)
    }

    @ViewBuilder
    func BatteryIconView() -> some View {
        AnimatedBatteryView(bLevel: store.batteryLevel, isCharging: false)
    }
}

@ViewBuilder
private func cornerOverlay(position: Alignment, @ViewBuilder content: () -> some View) -> some View {
    content()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position)
}

#Preview {
    DirectVideoCallView(store: .init(initialState: DirectVideoCallFeature.State(), reducer: {
        DirectVideoCallFeature()
    }))
}

#Preview("Test Battery") {
    DirectVideoCallView(store: .init(initialState: DirectVideoCallFeature.State(), reducer: {
        DirectVideoCallFeature()
            .body.dependency(\.batteryClient, .testValue)
    }))
}
