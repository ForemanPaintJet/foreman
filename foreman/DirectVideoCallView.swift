//
//  DirectVideoCallView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/22.
//

import Charts
import ComposableArchitecture
import OSLog
import SwiftUI

@Reducer
struct DirectVideoCallFeature {
    @ObservableState
    struct State: Equatable {
        var showConfig: Bool = false
        var showHumanPose: Bool = false
        var showWifiDetails: Bool = false
        var distanceFt: Double = 10.0
        var batteryLevel: Int = 100
        var wifiSignalStrength: Int = -45  // dBm
        var connectionQuality: Double = 0.85  // 0-1
        var networkSpeed: Double = 150.5  // Mbps
        var latency: Int = 12  // ms

        // Alert system
        var currentAlert: AlertType = .none

        enum AlertType: String, CaseIterable, Equatable {
            case none = "None"
            case green = "Green"
            case yellow = "Yellow"
            case red = "Red"

            var color: Color {
                switch self {
                case .none: .clear
                case .green: .green
                case .yellow: .yellow
                case .red: .red
                }
            }

            var message: String {
                switch self {
                case .none: ""
                case .green: "System Normal"
                case .yellow: "Warning Alert"
                case .red: "Critical Alert"
                }
            }
        }
    }

    @CasePathable
    enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case _internal(InternalAction)
        case delegate(DelegateAction)

        @CasePathable
        enum ViewAction: Equatable {
            case task
            case showConfig(Bool)
            case showHumanPose(Bool)
            case toggleWifiDetails
            case updateDistanceRandom
            case closeConfig
            case closeHumanPose
            case simulateAlert(State.AlertType)
        }

        @CasePathable
        enum InternalAction: Equatable {
            case batteryLevelChanged(Int)
        }

        enum DelegateAction: Equatable {
            // For future delegate logic
        }
    }

    enum CancelID {
        case battery
    }

    @Dependency(\.batteryClient) var batteryClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
    }

    func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding:
            return .none

        case .view(.task):
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
            state.distanceFt = Double.random(in: 1...100)
            return .none
        case .view(.closeConfig):
            state.showConfig = false
            return .none
        case .view(.closeHumanPose):
            state.showHumanPose = false
            return .none
        case .view(.simulateAlert(let alertType)):
            state.currentAlert = alertType
            return .none
        case ._internal(.batteryLevelChanged(let value)):
            state.batteryLevel = value
            return .none

        case .delegate:
            return .none
        }
    }
}

@ViewAction(for: DirectVideoCallFeature.self)
struct DirectVideoCallView: View {
    @Bindable var store: StoreOf<DirectVideoCallFeature>
    private let logger = Logger(subsystem: "foreman", category: "DirectVideoCallView")

    @Dependency(\.webRTCClient) var webRTCClientDependency

    var body: some View {
        VStack(spacing: 0) {
            // WiFi Details at the top (always visible when expanded)
            if store.showWifiDetails {
                WifiDetailsView(store: store)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        )
                    )
                    .zIndex(1)
            }

            ZStack {
                // Main content area
                VideoCallView(webRTCClient: WebRTCClientLive.shared.getClient())
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.all, store.currentAlert == .none ? 0 : 20)
                    .background(

                        Color.black.shadow(
                            .inner(
                                color: store.currentAlert == .none
                                    ? .black.opacity(0.4) : store.currentAlert.color,
                                radius: store.currentAlert == .none ? 8 : 30
                            ))

                    )
                    .animation(.easeInOut(duration: 0.5), value: store.currentAlert)

                cornerOverlay(position: .topLeading) {
                    VStack(spacing: 8) {
                        // Settings button
                        Button(action: {
                            send(.showConfig(true))
                        }) {
                            Image(systemName: "gearshape")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(.blue)
                                .padding(8)
                        }
                        .sheet(
                            isPresented: .init(
                                get: { store.showConfig },
                                set: { send(.showConfig($0)) }
                            )
                        ) {
                            ConfigPopupView(store: store)
                        }

                        // Alert simulation buttons
                        AlertSimulationView(store: store)
                    }
                }

                cornerOverlay(position: .topTrailing) {
                    HStack(spacing: 12) {
                        WifiSignalView(store: store)
                        HumanPoseButton(store: store)
                    }
                }

                cornerOverlay(position: .bottomLeading) {
                    RulerDistanceView(distance: store.distanceFt) {
                        send(.updateDistanceRandom)
                    }
                }

                cornerOverlay(position: .bottomTrailing) {
                    BatteryIconView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: store.showWifiDetails)
        }
        .task {
            send(.task)
            logger.info("🎥 DirectVideoCallView: Video viewer started with WebRTC client")
            let client = WebRTCClientLive.shared.getClient()
            logger.info(
                "🎥 DirectVideoCallView: Current video tracks count: \(client.remoteVideoTracks.count)"
            )
            for (index, track) in client.remoteVideoTracks.enumerated() {
                logger.info(
                    "🎥 Track \(index): User \(track.userId), Enabled: \(track.track?.isEnabled ?? false)"
                )
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
                    ForEach(0..<11) { i in
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
                    .offset(
                        x: CGFloat((distance - minFt) / (maxFt - minFt)) * (rulerWidth - markerSize)
                    )
                    .shadow(radius: 2)
                // Value label above marker
                Text(String(format: "%.1f ft", distance))
                    .font(.caption2)
                    .foregroundColor(.purple)
                    .offset(
                        x: CGFloat((distance - minFt) / (maxFt - minFt)) * (rulerWidth - markerSize)
                            - 10,
                        y: -22)
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
    func ConfigPopupView(store: StoreOf<DirectVideoCallFeature>) -> some View {
        VStack(spacing: 20) {
            Text("Configuration")
                .font(.headline)
            Divider()
            Text("Settings go here.")
            Button("Close") {
                send(.closeConfig)
            }
            .padding()
        }
        .padding()
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    func cornerButton(label: String) -> some View {
        Button(action: {
            logger.info("Button tapped at \(label)")
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
    func WifiSignalView(store: StoreOf<DirectVideoCallFeature>) -> some View {
        // Use SF Symbol for wifi icon and simulate signal strength
        VStack {
            Button(action: {
                send(.toggleWifiDetails)
            }) {
                Image(systemName: store.showWifiDetails ? "wifi.circle.fill" : "wifi")
                    .resizable()
                    .frame(width: 28, height: 22)
                    .foregroundColor(wifiSignalColor(for: store.wifiSignalStrength))
            }
            Text("Signal: \(store.wifiSignalStrength) dBm")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(8)
    }

    private func wifiSignalColor(for signalStrength: Int) -> Color {
        switch signalStrength {
        case -30...0: .green  // Excellent
        case -50...(-31): .blue  // Good
        case -70...(-51): .orange  // Fair
        default: .red  // Poor
        }
    }

    @ViewBuilder
    func BatteryIconView() -> some View {
        AnimatedBatteryView(bLevel: store.batteryLevel, isCharging: false)
    }

    @ViewBuilder
    func HumanPoseButton(store: StoreOf<DirectVideoCallFeature>) -> some View {
        Button(action: {
            send(.showHumanPose(true))
        }) {
            Image(systemName: "figure.run")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.orange)
                .padding(8)
        }
        .popover(
            isPresented: .init(
                get: { store.showHumanPose },
                set: { send(.showHumanPose($0)) }
            )
        ) {
            HumanPosePopoverView(store: store)
        }
    }

    @ViewBuilder
    func HumanPosePopoverView(store: StoreOf<DirectVideoCallFeature>) -> some View {
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
                    send(.closeHumanPose)
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
            SupportedPose(
                name: "Standing", icon: "figure.stand", category: "Basic", confidence: 95),
            SupportedPose(
                name: "Walking", icon: "figure.walk", category: "Movement", confidence: 92),
            SupportedPose(
                name: "Running", icon: "figure.run", category: "Movement", confidence: 88),
            SupportedPose(
                name: "Sitting", icon: "figure.seated.side", category: "Basic", confidence: 94),
            SupportedPose(
                name: "Raising Hand", icon: "hand.raised", category: "Gesture", confidence: 85),
            SupportedPose(
                name: "Arms Crossed", icon: "figure.arms.open", category: "Gesture", confidence: 80),
            SupportedPose(name: "Waving", icon: "hand.wave", category: "Gesture", confidence: 78),
            SupportedPose(
                name: "Squatting", icon: "figure.strengthtraining.traditional",
                category: "Exercise",
                confidence: 82),
            SupportedPose(
                name: "Push-up Position", icon: "figure.core.training", category: "Exercise",
                confidence: 86
            ),
            SupportedPose(
                name: "Yoga Pose", icon: "figure.mind.and.body", category: "Exercise",
                confidence: 75),
            SupportedPose(
                name: "Jumping", icon: "figure.jumprope", category: "Movement", confidence: 70),
            SupportedPose(
                name: "Dancing", icon: "figure.dance", category: "Movement", confidence: 68),
        ]
    }

    @ViewBuilder
    func AlertSimulationView(store: StoreOf<DirectVideoCallFeature>) -> some View {
        VStack(spacing: 4) {
            // Current alert status
            if store.currentAlert != .none {
                VStack(spacing: 2) {
                    Circle()
                        .fill(store.currentAlert.color)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0 + (store.currentAlert == .red ? 0.3 : 0.1))
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: store.currentAlert
                        )

                    Text(store.currentAlert.message)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(store.currentAlert.color)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 80)
                }
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            // Alert simulation buttons
            VStack(spacing: 4) {
                ForEach(DirectVideoCallFeature.State.AlertType.allCases, id: \.self) { alertType in
                    Button(action: {
                        send(.simulateAlert(alertType))
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(alertType.color)
                                .frame(width: 12, height: 12)

                            Text(alertType.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    alertType == store.currentAlert
                                        ? alertType.color.opacity(0.2) : Color.black.opacity(0.1))
                        )
                        .foregroundColor(alertType == .none ? .primary : alertType.color)
                    }
                }
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 2)
        }
    }

    @ViewBuilder
    func WifiDetailsView(store: StoreOf<DirectVideoCallFeature>) -> some View {
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

                Gauge(value: store.connectionQuality, in: 0...1) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int(store.connectionQuality * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(qualityColor(for: store.connectionQuality))
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
                    Text("\(store.networkSpeed, specifier: "%.1f")")
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
                    Text("\(store.latency)")
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
                send(.toggleWifiDetails)
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
        case 0.8...1.0: .green
        case 0.6..<0.8: .blue
        case 0.4..<0.6: .orange
        default: .red
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
        case "Basic": .blue
        case "Movement": .green
        case "Gesture": .orange
        case "Exercise": .purple
        default: .gray
        }
    }

    private var confidenceColor: Color {
        switch pose.confidence {
        case 90...100: .green
        case 80...89: .blue
        case 70...79: .orange
        default: .red
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
private func cornerOverlay(position: Alignment, @ViewBuilder content: () -> some View) -> some View
{
    content()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position)
}

#Preview {
    DirectVideoCallView(
        store: .init(
            initialState: DirectVideoCallFeature.State(),
            reducer: {
                DirectVideoCallFeature()
            }))
}

#Preview("Test Battery") {
    DirectVideoCallView(
        store: .init(
            initialState: DirectVideoCallFeature.State(),
            reducer: {
                DirectVideoCallFeature()
                    .body.dependency(\.batteryClient, .testValue)
            }))
}

struct MaskBorderAnimation1: View {
    @State private var angle: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.black)
                .frame(width: 200, height: 200)

            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(
                    .linearGradient(
                        colors: [.cyan, .indigo, .orange, .brown, .red, .blue], startPoint: .top,
                        endPoint: .bottom)
                )
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(angle))
                .mask {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white, lineWidth: 5)
                        .frame(width: 200, height: 200)
                }
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: angle)
        }
        .onAppear {
            angle = 360
        }
    }
}

#Preview("Mask Test") {
    MaskBorderAnimation1()
}
