//
//  ContentView.swift
//  AutoClinicConsult
//
//  3D scene host + dashboard/poster composition, mirroring the reference
//  app's ContentView.
//

import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var motion = MotionManager()
    @StateObject private var panelViewModel = ClinicPanelViewModel()
    @State private var clinicScene = ClinicScene()

    var body: some View {
        ZStack {
            SceneView(
                scene: clinicScene.scene,
                pointOfView: clinicScene.cameraNode,
                options: [.autoenablesDefaultLighting, .allowsCameraControl]
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    HomeContactView()
                    Spacer()
                }
                .padding()

                Spacer()

                HStack(alignment: .top) {
                    ClinicPanelView(viewModel: panelViewModel) { time in
                        clinicScene.setTimeOfDay(time)
                    }
                    .rotation3DEffect(.radians(motion.leanAngle), axis: (x: 0, y: 1, z: 0))
                    Spacer()
                }
                .padding()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    PosterVideoBillboard(vimeoID: "000000000", isMoving: motion.isMoving)
                        .frame(width: 220, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }
}

#Preview {
    ContentView()
}
