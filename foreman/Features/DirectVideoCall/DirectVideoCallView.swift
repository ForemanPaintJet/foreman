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

@ViewAction(for: DirectVideoCallFeature.self)
struct DirectVideoCallView: View {
    @Bindable var store: StoreOf<DirectVideoCallFeature>
    private let logger = Logger(subsystem: "foreman", category: "DirectVideoCallView")


    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                // Main content area
                VideoCallView(remoteVideoTracks: store.remoteVideoTracks)
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
                    // Alert simulation buttons
                    AlertSimulationView(store: store)
                }



            }
        }
        .task {
            send(.task)
            logger.info("🎥 DirectVideoCallView: Video viewer started with WebRTC client")
            logger.info("🎥 DirectVideoCallView: Video viewer started")
        }
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
