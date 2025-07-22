//
//  WebRTCMqttView.swift
//  foreman
//
//  Created by Jed Lu on 2025/7/18.
//

import ComposableArchitecture
import Logging
import SwiftUI

struct WebRTCMqttView: View {
    @Bindable var store: StoreOf<WebRTCMqttFeature>

    // SwiftLog logger instance
    private let logger = Logger(label: "WebRTCMqttView")

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.orange.gradient)
                .ignoresSafeArea()
            Group {
                if store.isJoinedToRoom {
                    DirectVideoCallView()
                } else {
                    VStack {
                        Spacer()
                        VStack(spacing: 20) {
                            // MQTT Connection Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("MQTT Broker")
                                    .font(.headline)
                                TextField(
                                    "Address", text: $store.mqttInfo.address.sending(\.view.updateMqttAddress)
                                )
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField(
                                    "Port", value: $store.mqttInfo.port.sending(\.view.updateMqttPort),
                                    format: .number
                                )
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("User ID", text: $store.userId.sending(\.view.updateUserId))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Room ID", text: $store.roomId.sending(\.view.updateRoomId))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                HStack {
                                    Button("Connect") {
                                        logger.info("User tapped Connect")
                                        store.send(.view(.connectToBroker))
                                    }
                                    .disabled(store.connectionStatus == .connected)
                                    
                                    Button("Join Room") {
                                        logger.info("User tapped Join Room")
                                        store.send(.view(.joinRoom))
                                    }
                                    .disabled(store.connectionStatus != .connected)
                                    
                                    Button("Disconnect") {
                                        logger.info("User tapped Disconnect")
                                        store.send(.view(.disconnect))
                                    }
                                    .disabled(store.connectionStatus != .connected)
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        }
                        .frame(maxWidth: 400)
                        Spacer()
                    }
                    .navigationTitle("WebRTC MQTT")
                    .padding()
                }
            }
        }
        .onAppear {
            logger.info("WebRTCMqttView appeared")
            store.send(.view(.onAppear))
        }
        .onDisappear {
            logger.info("WebRTCMqttView disappeared")
            store.send(.view(.onDisappear))
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#Preview {
    WebRTCMqttView(
        store: .init(
            initialState: WebRTCMqttFeature.State(),
            reducer: {
                WebRTCMqttFeature()
            }))
}
