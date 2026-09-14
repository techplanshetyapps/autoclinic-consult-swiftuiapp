import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var motion = MotionManager()
    @StateObject private var panelViewModel = ClinicPanelViewModel()
    @State private var clinicScene = ClinicScene()
    
    // UI Interaction States
    @State private var hoveredNodeName: String? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var activeNotification: String? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. SceneKit Container View
                SceneKitContainerView(
                    scene: clinicScene.scene,
                    pointOfView: clinicScene.cameraNode,
                    onHover: { nodeName, location in
                        if let name = nodeName {
                            hoveredNodeName = formatNodeTitle(name)
                            hoverLocation = location
                        } else {
                            hoveredNodeName = nil
                        }
                    },
                    onClick: { nodeName in
                        if let name = nodeName {
                            triggerClickNotification(for: name)
                        }
                    }
                )
                .ignoresSafeArea()

                // 2. Hover Tooltip
                if let hovered = hoveredNodeName {
                    VStack {
                        Text(hovered)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                        Spacer()
                    }
                    .position(x: hoverLocation.x, y: max(hoverLocation.y - 30, 40))
                    .allowsHitTesting(false)
                }

                // 3. Click Notification Banner
                if let notification = activeNotification {
                    VStack {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text(notification)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: activeNotification)
                }

                // 4. Main UI Controls
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

                // 5. Video Billboard Component
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
        }
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    private func triggerClickNotification(for nodeName: String) {
        let title = formatNodeTitle(nodeName)
        activeNotification = "Selected: \(title)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if activeNotification == "Selected: \(title)" {
                activeNotification = nil
            }
        }
    }

    private func formatNodeTitle(_ name: String) -> String {
        switch name {
        case "clinicAnchor": return "Main Clinic Building"
        case "crossGlow": return "Emergency Medical Services"
        case "bayLight": return "Ambulance Bay"
        default: return name.capitalized
        }
    }
}

// MARK: - Native UIViewRepresentable SceneKit Container

struct SceneKitContainerView: UIViewRepresentable {
    let scene: SCNScene
    let pointOfView: SCNNode?
    var onHover: (String?, CGPoint) -> Void
    var onClick: (String?) -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.pointOfView = pointOfView
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .black

        // Setup Tap Recognizer for 3D Hit Testing
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)

        // Setup Hover Recognizer for Mac/iPad Catalyst support
        let hoverGesture = UIHoverGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleHover(_:)))
        scnView.addGestureRecognizer(hoverGesture)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
        uiView.pointOfView = pointOfView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: SceneKitContainerView

        init(_ parent: SceneKitContainerView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            let location = gesture.location(in: scnView)
            
            let options: [SCNHitTestOption: Any] = [
                .boundingBoxOnly: false,
                .ignoreChildNodes: false
            ]

            let hits = scnView.hitTest(location, options: options)

            if let firstHit = hits.first {
                let name = findNamedParent(node: firstHit.node)
                parent.onClick(name)
            }
        }

        @objc func handleHover(_ gesture: UIHoverGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            let location = gesture.location(in: scnView)

            let options: [SCNHitTestOption: Any] = [
                .boundingBoxOnly: false,
                .ignoreChildNodes: false
            ]

            switch gesture.state {
            case .changed, .began:
                let hits = scnView.hitTest(location, options: options)
                
                if let firstHit = hits.first, let name = findNamedParent(node: firstHit.node) {
                    parent.onHover(name, location)
                } else {
                    parent.onHover(nil, location)
                }
            case .ended, .cancelled:
                parent.onHover(nil, location)
            default:
                break
            }
        }
        
        private func findNamedParent(node: SCNNode) -> String? {
                var current: SCNNode? = node
                while let target = current {
                    if let name = target.name, !name.isEmpty {
                        return name
                    }
                    current = target.parent
                }
                return nil
        }
    }
}
