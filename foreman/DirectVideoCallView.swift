//
//  DirectVideoCallView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/22.
//

import ComposableArchitecture
import SwiftUI
import Charts

@Reducer
struct DirectVideoCallFeature {
    @ObservableState
    struct State: Equatable {
        var showConfig: Bool = false
        var showHumanPose: Bool = false
        var showWifiDetails: Bool = false
        var distanceFt: Double = 10.0
        var batteryLevel: Int = 100
        var wifiSignalStrength: Int = -45 // dBm
        var connectionQuality: Double = 0.85 // 0-1
        var networkSpeed: Double = 150.5 // Mbps
        var latency: Int = 12 // ms
    }

    enum Action: TCAFeatureAction {
        @CasePathable
        enum ViewAction: Equatable {
            case onAppear
            case showConfig(Bool)
            case showHumanPose(Bool)
            case toggleWifiDetails
            case updateDistanceRandom
            case closeConfig
            case closeHumanPose
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
            case .view(.showHumanPose(let show)):
                state.showHumanPose = show
                return .none
            case .view(.toggleWifiDetails):
                state.showWifiDetails.toggle()
                return .none
            case .view(.updateDistanceRandom):
                state.distanceFt = Double.random(in: 1 ... 100)
                return .none
            case .view(.closeConfig):
                state.showConfig = false
                return .none
            case .view(.closeHumanPose):
                state.showHumanPose = false
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
        WithViewStore(store, observe: { $0 }, content: { viewStore in
            VStack(spacing: 0) {
                // WiFi Details at the top (always visible when expanded)
                if viewStore.showWifiDetails {
                    WifiDetailsView(viewStore: viewStore)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                        .zIndex(1)
                }
                
                // Main content area
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
                        HStack(spacing: 12) {
                            WifiSignalView(viewStore: viewStore)
                            HumanPoseButton(viewStore: viewStore)
                        }
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
                .animation(.easeInOut(duration: 0.3), value: viewStore.showWifiDetails)
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
        })
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
    func WifiSignalView(viewStore: ViewStoreOf<DirectVideoCallFeature>) -> some View {
        // Use SF Symbol for wifi icon and simulate signal strength
        VStack {
            Button(action: {
                viewStore.send(.view(.toggleWifiDetails))
            }) {
                Image(systemName: viewStore.showWifiDetails ? "wifi.circle.fill" : "wifi")
                    .resizable()
                    .frame(width: 28, height: 22)
                    .foregroundColor(wifiSignalColor(for: viewStore.wifiSignalStrength))
            }
            Text("Signal: \(viewStore.wifiSignalStrength) dBm")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(8)
    }
    
    private func wifiSignalColor(for signalStrength: Int) -> Color {
        switch signalStrength {
        case -30...0: return .green      // Excellent
        case -50...(-31): return .blue     // Good
        case -70...(-51): return .orange   // Fair
        default: return .red             // Poor
        }
    }

    @ViewBuilder
    func BatteryIconView() -> some View {
        AnimatedBatteryView(bLevel: store.batteryLevel, isCharging: false)
    }
    
    @ViewBuilder
    func HumanPoseButton(viewStore: ViewStoreOf<DirectVideoCallFeature>) -> some View {
        Button(action: {
            viewStore.send(.view(.showHumanPose(true)))
        }) {
            Image(systemName: "figure.run")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.orange)
                .padding(8)
        }
        .popover(isPresented: viewStore.binding(get: \.showHumanPose, send: { .view(.showHumanPose($0)) })) {
            HumanPosePopoverView(viewStore: viewStore)
        }
    }
    
    @ViewBuilder
    func HumanPosePopoverView(viewStore: ViewStoreOf<DirectVideoCallFeature>) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Supported Poses")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Button("Close") {
                    viewStore.send(.view(.closeHumanPose))
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            
            Divider()
            
            // Supported Poses List
            List(supportedPoses, id: \.name) { pose in
                SupportedPoseRow(pose: pose)
            }
            .listStyle(.plain)
            .frame(maxHeight: 350)
        }
        .frame(width: 320, height: 400)
    }
    
    private var supportedPoses: [SupportedPose] {
        [
            SupportedPose(name: "Standing", icon: "figure.stand", category: "Basic", confidence: 95),
            SupportedPose(name: "Walking", icon: "figure.walk", category: "Movement", confidence: 92),
            SupportedPose(name: "Running", icon: "figure.run", category: "Movement", confidence: 88),
            SupportedPose(name: "Sitting", icon: "figure.seated.side", category: "Basic", confidence: 94),
            SupportedPose(name: "Raising Hand", icon: "hand.raised", category: "Gesture", confidence: 85),
            SupportedPose(name: "Arms Crossed", icon: "figure.arms.open", category: "Gesture", confidence: 80),
            SupportedPose(name: "Waving", icon: "hand.wave", category: "Gesture", confidence: 78),
            SupportedPose(name: "Squatting", icon: "figure.strengthtraining.traditional", category: "Exercise", confidence: 82),
            SupportedPose(name: "Push-up Position", icon: "figure.core.training", category: "Exercise", confidence: 86),
            SupportedPose(name: "Yoga Pose", icon: "figure.mind.and.body", category: "Exercise", confidence: 75),
            SupportedPose(name: "Jumping", icon: "figure.jumprope", category: "Movement", confidence: 70),
            SupportedPose(name: "Dancing", icon: "figure.dance", category: "Movement", confidence: 68)
        ]
    }
    
    @ViewBuilder
    func WifiDetailsView(viewStore: ViewStoreOf<DirectVideoCallFeature>) -> some View {
        HStack(spacing: 16) {
            // Signal Strength Chart
            VStack(alignment: .leading, spacing: 6) {
                Text("Signal Strength")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Chart(signalHistory, id: \.time) { data in
                    LineMark(
                        x: .value("Time", data.time),
                        y: .value("Signal", data.signal)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", data.time),
                        y: .value("Signal", data.signal)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                }
                .frame(width: 120, height: 50)
                .chartYScale(domain: -80...0)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
            
            Divider()
                .frame(height: 50)
            
            // Connection Quality Gauge
            VStack(spacing: 4) {
                Text("Quality")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Gauge(value: viewStore.connectionQuality, in: 0...1) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int(viewStore.connectionQuality * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(qualityColor(for: viewStore.connectionQuality))
                .frame(width: 50, height: 50)
            }
            
            Divider()
                .frame(height: 50)
            
            // Network Stats
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(viewStore.networkSpeed, specifier: "%.1f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Mbps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(viewStore.latency)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .frame(height: 50)
            
            // Network Speed Chart
            VStack(alignment: .leading, spacing: 6) {
                Text("Network Speed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                Chart(speedHistory, id: \.time) { data in
                    BarMark(
                        x: .value("Time", data.time),
                        y: .value("Speed", data.speed)
                    )
                    .foregroundStyle(.green.gradient)
                }
                .frame(width: 120, height: 50)
                .chartYScale(domain: 0...200)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
            
            Spacer()
            
            // Close button
            Button(action: {
                viewStore.send(.view(.toggleWifiDetails))
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
    
    private func qualityColor(for quality: Double) -> Color {
        switch quality {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue  
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    private var signalHistory: [SignalData] {
        (0..<10).map { i in
            SignalData(
                time: i,
                signal: Int.random(in: -70...(-30))
            )
        }
    }
    
    private var speedHistory: [SpeedData] {
        (0..<8).map { i in
            SpeedData(
                time: i,
                speed: Double.random(in: 50...180)
            )
        }
    }
}

struct SupportedPose {
    let name: String
    let icon: String
    let category: String
    let confidence: Int
}

struct SupportedPoseRow: View {
    let pose: SupportedPose
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: pose.icon)
                .font(.system(size: 24))
                .foregroundColor(categoryColor)
                .frame(width: 32)
            
            // Pose info
            VStack(alignment: .leading, spacing: 2) {
                Text(pose.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(pose.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Confidence
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(pose.confidence)%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(confidenceColor)
                
                Text("confidence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var categoryColor: Color {
        switch pose.category {
        case "Basic": return .blue
        case "Movement": return .green
        case "Gesture": return .orange
        case "Exercise": return .purple
        default: return .gray
        }
    }
    
    private var confidenceColor: Color {
        switch pose.confidence {
        case 90...100: return .green
        case 80...89: return .blue
        case 70...79: return .orange
        default: return .red
        }
    }
}

struct SignalData {
    let time: Int
    let signal: Int
}

struct SpeedData {
    let time: Int
    let speed: Double
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
