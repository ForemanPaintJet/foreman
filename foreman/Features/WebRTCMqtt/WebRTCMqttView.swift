//
//  WebRTCMqttView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/18.
//

import ComposableArchitecture
import OSLog
import SwiftUI

@ViewAction(for: WebRTCMqttFeature.self)
struct WebRTCMqttView: View {
    @Bindable var store: StoreOf<WebRTCMqttFeature>
    let namespace: Namespace.ID?

    private let logger = Logger(subsystem: "foreman", category: "WebRTCMqttView")
    
    init(store: StoreOf<WebRTCMqttFeature>, namespace: Namespace.ID? = nil) {
        self.store = store
        self.namespace = namespace
    }

    var body: some View {
        ZStack {
            Group {
                if store.isJoinedToRoom {
                    DirectVideoCallView(
                        store: store.scope(state: \.directVideoCall, action: \.directVideoCall)
                    )
                } else {
                    VStack {
                        Spacer()
                        VStack(spacing: 20) {
                            // Video Icon Header
                            HStack {
                                if let namespace = namespace {
                                    Text("FOREMAN TECH")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .matchedGeometryEffect(id: "titleText", in: namespace)
                                    Image("logo")
                                        .scaleEffect(1) // 保持 1:1 大小
                                        .rotationEffect(.degrees(store.logoRotationAngle))
                                        .matchedGeometryEffect(id: "videoIcon", in: namespace)
                                }
                            }
                            .padding(.bottom, 8)
                            
                            // MQTT Connection Section - 延遲顯示
                            VStack(alignment: .leading, spacing: 12) {
                                Text("MQTT Broker")
                                    .font(.headline)
                                TextField(
                                    "Address",
                                    text: $store.mqttInfo.address
                                )
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField(
                                    "Port",
                                    value: $store.mqttInfo.port,
                                    format: .number
                                )
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField(
                                    "User ID", text: $store.userId
                                )
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                                HStack {
                                    Button("Connect") {
                                        logger.info("User tapped Connect")
                                        send(.connectToBroker)
                                    }
                                    .disabled(store.connectionStatus == .connected)

                                    Button("Join Room") {
                                        logger.info("User tapped Join Room")
                                        send(.joinRoom)
                                    }
                                    .disabled(store.connectionStatus != .connected)

                                    Button("Disconnect") {
                                        logger.info("User tapped Disconnect")
                                        send(.disconnect)
                                    }
                                    .disabled(store.connectionStatus != .connected)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        }
                        .frame(maxWidth: 400)
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .task {
            logger.info("WebRTCMqttView task started")
            send(.task)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#Preview {
    @Namespace var namespace
    return WebRTCMqttView(
        store: .init(
            initialState: WebRTCMqttFeature.State(),
            reducer: {
                WebRTCMqttFeature()
            }),
        namespace: namespace
    )
}
