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
import WebRTC
import WebRTCCore

@ViewAction(for: DirectVideoCallFeature.self)
struct DirectVideoCallView: View {
    @Bindable var store: StoreOf<DirectVideoCallFeature>
    private let logger = Logger(subsystem: "foreman", category: "DirectVideoCallView")


    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                // Dual camera layout
                DualCameraView(
                    leftCameraTrack: store.leftCameraTrack,
                    rightCameraTrack: store.rightCameraTrack
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .background(Color.black)




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





}


@ViewBuilder
private func cornerOverlay(position: Alignment, @ViewBuilder content: () -> some View) -> some View
{
    content()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position)
}

struct DualCameraView: View {
    let leftCameraTrack: VideoTrackInfo?
    let rightCameraTrack: VideoTrackInfo?
    
    var body: some View {
        HStack(spacing: 8) {
            // Left Camera
            CameraView(
                videoTrack: leftCameraTrack,
                label: "Left Camera"
            )
            
            // Right Camera
            CameraView(
                videoTrack: rightCameraTrack,
                label: "Right Camera"
            )
        }
        .background(Color.black)
    }
}

struct CameraView: View {
    let videoTrack: VideoTrackInfo?
    let label: String
    
    var body: some View {
        ZStack {
            if let track = videoTrack {
                VideoView(videoTrack: track.track)
                    .aspectRatio(16/9, contentMode: .fit)
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No Signal")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
            }
            
            // Camera label overlay
            VStack {
                HStack {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    Spacer()
                }
                Spacer()
            }
            .padding(8)
        }
        .background(Color.black)
        .cornerRadius(8)
    }
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
