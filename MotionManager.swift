//
//  MotionManager.swift
//  AutoClinicConsult
//
//  Reads device roll via CoreMotion and low-pass filters it into `leanAngle`.
//  Same signal pattern as the reference app: drives 3D lean/parallax,
//  poster<->video swap, and fountain (here: ambulance-bay light) state.
//

import Foundation
import CoreMotion
import Combine

final class MotionManager: ObservableObject {
    @Published var leanAngle: Double = 0.0       // radians, low-pass filtered device roll
    @Published var isMoving: Bool = false         // derived from rate of change of roll

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var lastRoll: Double = 0.0
    private var lastTimestamp: TimeInterval = 0.0

    // Tunables (kept identical in spirit to the reference app)
    private let lowPassAlpha: Double = 0.12
    private let movingThreshold: Double = 0.015 // rad/sample considered "moving"

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let roll = motion.attitude.roll
            let delta = abs(roll - self.lastRoll)
            self.lastRoll = roll

            let filtered = self.leanAngle + self.lowPassAlpha * (roll - self.leanAngle)
            let moving = delta > self.movingThreshold

            DispatchQueue.main.async {
                self.leanAngle = filtered
                self.isMoving = moving
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
