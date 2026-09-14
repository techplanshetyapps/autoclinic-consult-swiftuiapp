//
//  ClinicScene.swift
//  AutoClinicConsult
//
//  SceneKit scene analogous to the reference app's DashboardScene, but the
//  procedural "buildings" are replaced with procedural "hospitals" — each
//  hospital node is built from EXACTLY 20 small child elements (enumerated
//  below). The reference app's Day/Afternoon/Night sky is kept as three
//  presets, with "Night" renamed to "Eve" throughout (enum case, API, and UI
//  label), and it now includes a sun with clouds for Day/Afternoon and a
//  moon with clouds for Eve.
//

import SceneKit
import UIKit

enum TimeOfDay: String, CaseIterable, Identifiable {
    case day = "Day"
    case afternoon = "Afternoon"
    case eve = "Eve"           // renamed from "Night"
    var id: String { rawValue }
}

final class ClinicScene {

    let scene = SCNScene()
    let cameraNode = SCNNode()
    private(set) var clinicNode = SCNNode()      // the "dashboard"/panel anchor node
    private var skyNode = SCNNode()
    private var sunNode: SCNNode?
    private var moonNode: SCNNode?
    private var cloudNodes: [SCNNode] = []
    private var hospitalWindowMaterials: [SCNMaterial] = []
    private var keyLight = SCNNode()
    private var ambientLight = SCNNode()
    private var rimLight = SCNNode()

    init() {
        buildCamera()
        buildLights()
        buildSky()
        buildGround()
        buildHospitalSkyline()
        buildClinicAnchorNode()
        setTimeOfDay(.day)
    }

    // MARK: - Camera

    private func buildCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 55
        camera.zNear = 0.1
        camera.zFar = 500
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 6, 18)
        cameraNode.eulerAngles = SCNVector3(-0.12, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }

    // MARK: - Lights

    private func buildLights() {
        let key = SCNLight()
        key.type = .directional
        key.castsShadow = true
        keyLight.light = key
        keyLight.eulerAngles = SCNVector3(-Double.pi / 3, Double.pi / 4, 0)
        scene.rootNode.addChildNode(keyLight)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambientLight.light = ambient
        scene.rootNode.addChildNode(ambientLight)

        let rim = SCNLight()
        rim.type = .directional
        rimLight.light = rim
        rimLight.eulerAngles = SCNVector3(-Double.pi / 6, -Double.pi / 1.5, 0)
        scene.rootNode.addChildNode(rimLight)
    }

    // MARK: - Sky (Day / Afternoon / Eve)

    private func buildSky() {
        let skyPlane = SCNPlane(width: 400, height: 220)
        let skyMaterial = SCNMaterial()
        skyMaterial.lightingModel = .constant
        skyPlane.materials = [skyMaterial]
        skyNode = SCNNode(geometry: skyPlane)
        skyNode.position = SCNVector3(0, 30, -140)
        scene.rootNode.addChildNode(skyNode)

        // Sun — visible Day / Afternoon
        let sunGeo = SCNSphere(radius: 6)
        let sunMat = SCNMaterial()
        sunMat.lightingModel = .constant
        sunGeo.materials = [sunMat]
        let sun = SCNNode(geometry: sunGeo)
        sun.position = SCNVector3(60, 45, -130)
        scene.rootNode.addChildNode(sun)
        sunNode = sun

        // Moon — visible Eve, with craters via a bump-free shaded sphere
        let moonGeo = SCNSphere(radius: 4.2)
        let moonMat = SCNMaterial()
        moonMat.lightingModel = .constant
        moonMat.diffuse.contents = UIColor(white: 0.92, alpha: 1.0)
        moonGeo.materials = [moonMat]
        let moon = SCNNode(geometry: moonGeo)
        moon.position = SCNVector3(-55, 48, -130)
        scene.rootNode.addChildNode(moon)
        moonNode = moon

        // Clouds — five soft cloud clusters, reused for every time of day,
        // recolored per preset (bright white by day, ember by afternoon,
        // slate-blue drifting past the moon by eve).
        for i in 0..<5 {
            let cloud = makeCloudCluster()
            let x = Double(i - 2) * 26 + Double.random(in: -6...6)
            let y = 34 + Double.random(in: -4...8)
            let z = -125 + Double.random(in: -10...10)
            cloud.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(cloud)
            cloudNodes.append(cloud)
        }
    }

    /// A small cluster of 3 overlapping flattened spheres approximating a cloud puff.
    private func makeCloudCluster() -> SCNNode {
        let cluster = SCNNode()
        let puffCount = 3
        for p in 0..<puffCount {
            let radius = CGFloat.random(in: 3.0...5.5)
            let geo = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = UIColor.white
            mat.transparency = 0.92
            geo.materials = [mat]
            let puff = SCNNode(geometry: geo)
            puff.position = SCNVector3(Double(p) * 3.5 - 3.5, Double.random(in: -0.6...0.6), 0)
            puff.scale = SCNVector3(1.0, 0.55, 1.0)
            cluster.addChildNode(puff)
        }
        return cluster
    }

    // MARK: - Ground

    private func buildGround() {
        let ground = SCNFloor()
        ground.reflectivity = 0.02
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.18, green: 0.19, blue: 0.21, alpha: 1.0)
        mat.roughness.contents = 0.9
        ground.materials = [mat]
        let node = SCNNode(geometry: ground)
        node.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Hospital skyline (buildings -> hospitals)

    private func buildHospitalSkyline() {
        let positions: [(x: Double, z: Double, h: Double)] = [
            (-24, -30, 26), (-12, -38, 34), (0, -34, 42),
            (14, -40, 30), (26, -32, 22), (-36, -44, 18)
        ]
        for (i, p) in positions.enumerated() {
            let hospital = makeHospital(height: p.h, seed: i)
            hospital.position = SCNVector3(p.x, 0, p.z)
            scene.rootNode.addChildNode(hospital)
        }
    }

    /// Builds ONE hospital node composed of exactly 20 small procedural
    /// elements (numbered 1-20 below), mirroring the reference app's
    /// procedural skyscraper but re-themed as a hospital tower.
    private func makeHospital(height: Double, seed: Int) -> SCNNode {
        let hospital = SCNNode()
        let width: CGFloat = 9
        let depth: CGFloat = 9
        let h = CGFloat(height)

        // 1. Main tower body
        let bodyGeo = SCNBox(width: width, height: h, length: depth, chamferRadius: 0.15)
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = UIColor(red: 0.86, green: 0.87, blue: 0.89, alpha: 1.0)
        bodyMat.roughness.contents = 0.75
        bodyGeo.materials = [bodyMat]
        let body = SCNNode(geometry: bodyGeo)
        body.position = SCNVector3(0, h / 2, 0)
        hospital.addChildNode(body)

        // 2. Window grid — front face
        let windowFront = makeWindowGrid(width: width, height: h)
        windowFront.position = SCNVector3(0, h / 2, Double(depth / 2) + 0.02)
        hospital.addChildNode(windowFront)
        hospitalWindowMaterials.append(windowFront.geometry!.materials[0])

        // 3. Window grid — side face
        let windowSide = makeWindowGrid(width: depth, height: h)
        windowSide.eulerAngles = SCNVector3(0, Double.pi / 2, 0)
        windowSide.position = SCNVector3(Double(width / 2) + 0.02, h / 2, 0)
        hospital.addChildNode(windowSide)
        hospitalWindowMaterials.append(windowSide.geometry!.materials[0])

        // 4. Floor ledge bands (stacked thin boxes every ~4 floors)
        let ledgeBands = SCNNode()
        var ledgeY: CGFloat = 4
        while ledgeY < h {
            let ledgeGeo = SCNBox(width: width + 0.3, height: 0.18, length: depth + 0.3, chamferRadius: 0.02)
            let ledgeMat = SCNMaterial()
            ledgeMat.diffuse.contents = UIColor(white: 0.65, alpha: 1.0)
            ledgeGeo.materials = [ledgeMat]
            let ledge = SCNNode(geometry: ledgeGeo)
            ledge.position = SCNVector3(0, Double(ledgeY), 0)
            ledgeBands.addChildNode(ledge)
            ledgeY += 4
        }
        hospital.addChildNode(ledgeBands)

        // 5. Corner trim pillar (left)
        let pillarL = makeCornerPillar(height: h)
        pillarL.position = SCNVector3(-Double(width / 2), Double(h / 2), -Double(depth / 2))
        hospital.addChildNode(pillarL)

        // 6. Corner trim pillar (right)
        let pillarR = makeCornerPillar(height: h)
        pillarR.position = SCNVector3(Double(width / 2), Double(h / 2), -Double(depth / 2))
        hospital.addChildNode(pillarR)

        // 7. Rooftop setback tier
        let setbackGeo = SCNBox(width: width * 0.6, height: 1.4, length: depth * 0.6, chamferRadius: 0.08)
        let setbackMat = SCNMaterial()
        setbackMat.diffuse.contents = UIColor(white: 0.8, alpha: 1.0)
        setbackGeo.materials = [setbackMat]
        let setback = SCNNode(geometry: setbackGeo)
        setback.position = SCNVector3(0, Double(h) + 0.7, 0)
        hospital.addChildNode(setback)

        // 8. Rooftop antenna
        let antennaGeo = SCNCylinder(radius: 0.06, height: 3.0)
        let antennaMat = SCNMaterial()
        antennaMat.diffuse.contents = UIColor(white: 0.3, alpha: 1.0)
        antennaGeo.materials = [antennaMat]
        let antenna = SCNNode(geometry: antennaGeo)
        antenna.position = SCNVector3(Double(width) * 0.2, Double(h) + 2.9, Double(depth) * 0.2)
        hospital.addChildNode(antenna)

        // 9. Rooftop AC / chiller unit
        let acGeo = SCNBox(width: 1.4, height: 0.9, length: 1.4, chamferRadius: 0.05)
        let acMat = SCNMaterial()
        acMat.diffuse.contents = UIColor(white: 0.45, alpha: 1.0)
        acGeo.materials = [acMat]
        let ac = SCNNode(geometry: acGeo)
        ac.position = SCNVector3(-Double(width) * 0.22, Double(h) + 1.85, -Double(depth) * 0.2)
        hospital.addChildNode(ac)

        // 10. Rooftop water tank
        let tankGeo = SCNCylinder(radius: 0.7, height: 1.6)
        let tankMat = SCNMaterial()
        tankMat.diffuse.contents = UIColor(red: 0.55, green: 0.4, blue: 0.3, alpha: 1.0)
        tankGeo.materials = [tankMat]
        let tank = SCNNode(geometry: tankGeo)
        tank.position = SCNVector3(Double(width) * -0.05, Double(h) + 2.2, Double(depth) * 0.28)
        hospital.addChildNode(tank)

        // 11. Helipad platform (only on the tallest tower silhouette look)
        let padGeo = SCNCylinder(radius: 2.2, height: 0.12)
        let padMat = SCNMaterial()
        padMat.diffuse.contents = UIColor(white: 0.15, alpha: 1.0)
        padGeo.materials = [padMat]
        let pad = SCNNode(geometry: padGeo)
        pad.position = SCNVector3(0, Double(h) + 1.5, 0)
        hospital.addChildNode(pad)

        // 12. Helipad "H" marking
        let hMarkGeo = SCNText(string: "H", extrusionDepth: 0.02)
        hMarkGeo.font = UIFont.boldSystemFont(ofSize: 3)
        let hMat = SCNMaterial()
        hMat.diffuse.contents = UIColor.yellow
        hMarkGeo.materials = [hMat]
        let hMark = SCNNode(geometry: hMarkGeo)
        hMark.scale = SCNVector3(0.3, 0.3, 0.01)
        hMark.position = SCNVector3(-0.6, Double(h) + 1.57, -0.6)
        hMark.eulerAngles = SCNVector3(-Double.pi / 2, 0, 0)
        hospital.addChildNode(hMark)

        // 13. Ground-floor entrance canopy
        let canopyGeo = SCNBox(width: 4.5, height: 0.25, length: 2.2, chamferRadius: 0.02)
        let canopyMat = SCNMaterial()
        canopyMat.diffuse.contents = UIColor(red: 0.1, green: 0.35, blue: 0.65, alpha: 1.0)
        canopyGeo.materials = [canopyMat]
        let canopy = SCNNode(geometry: canopyGeo)
        canopy.position = SCNVector3(0, 3.0, Double(depth / 2) + 1.1)
        hospital.addChildNode(canopy)

        // 14. Entrance glass door
        let doorGeo = SCNBox(width: 2.2, height: 2.6, length: 0.08, chamferRadius: 0.01)
        let doorMat = SCNMaterial()
        doorMat.diffuse.contents = UIColor(red: 0.5, green: 0.75, blue: 0.9, alpha: 0.6)
        doorMat.transparency = 0.7
        doorGeo.materials = [doorMat]
        let door = SCNNode(geometry: doorGeo)
        door.position = SCNVector3(0, 1.3, Double(depth / 2) + 0.05)
        hospital.addChildNode(door)

        // 15. Red cross sign (static plate)
        let crossGeo = SCNPlane(width: 1.6, height: 1.6)
        let crossMat = SCNMaterial()
        crossMat.diffuse.contents = makeCrossImage()
        crossMat.lightingModel = .constant
        crossGeo.materials = [crossMat]
        let cross = SCNNode(geometry: crossGeo)
        cross.position = SCNVector3(0, Double(h) * 0.72, Double(depth / 2) + 0.06)
        hospital.addChildNode(cross)

        // 16. Red cross glow panel (emissive backing, brighter at Eve)
        let glowGeo = SCNPlane(width: 2.0, height: 2.0)
        let glowMat = SCNMaterial()
        glowMat.diffuse.contents = UIColor.clear
        glowMat.emission.contents = UIColor.red
        glowMat.lightingModel = .constant
        glowMat.transparency = 0.0
        glowGeo.materials = [glowMat]
        let glow = SCNNode(geometry: glowGeo)
        glow.position = SCNVector3(0, Double(h) * 0.72, Double(depth / 2) + 0.04)
        glow.name = "crossGlow"
        hospital.addChildNode(glow)

        // 17. Ambulance bay roller door
        let bayGeo = SCNBox(width: 3.2, height: 2.8, length: 0.12, chamferRadius: 0.02)
        let bayMat = SCNMaterial()
        bayMat.diffuse.contents = UIColor(white: 0.5, alpha: 1.0)
        bayGeo.materials = [bayMat]
        let bay = SCNNode(geometry: bayGeo)
        bay.position = SCNVector3(Double(width) * 0.45, 1.4, Double(depth / 2) + 0.06)
        hospital.addChildNode(bay)

        // 18. Ambulance bay warning light (amber, pulses conceptually at Eve)
        let bayLightGeo = SCNSphere(radius: 0.18)
        let bayLightMat = SCNMaterial()
        bayLightMat.diffuse.contents = UIColor.orange
        bayLightMat.emission.contents = UIColor.orange
        bayLightGeo.materials = [bayLightMat]
        let bayLight = SCNNode(geometry: bayLightGeo)
        bayLight.position = SCNVector3(Double(width) * 0.45, 2.9, Double(depth / 2) + 0.1)
        bayLight.name = "bayLight"
        hospital.addChildNode(bayLight)

        // 19. Ground planter box
        let planterGeo = SCNBox(width: 1.4, height: 0.5, length: 0.8, chamferRadius: 0.05)
        let planterMat = SCNMaterial()
        planterMat.diffuse.contents = UIColor(red: 0.3, green: 0.22, blue: 0.15, alpha: 1.0)
        planterGeo.materials = [planterMat]
        let planter = SCNNode(geometry: planterGeo)
        planter.position = SCNVector3(-Double(width) * 0.45, 0.25, Double(depth / 2) + 1.4)
        hospital.addChildNode(planter)

        // 20. Base pedestal / foundation lip
        let baseGeo = SCNBox(width: width + 1.0, height: 0.5, length: depth + 1.0, chamferRadius: 0.08)
        let baseMat = SCNMaterial()
        baseMat.diffuse.contents = UIColor(white: 0.55, alpha: 1.0)
        baseGeo.materials = [baseMat]
        let base = SCNNode(geometry: baseGeo)
        base.position = SCNVector3(0, 0.25, 0)
        hospital.addChildNode(base)

        // sanity: exactly 20 direct-purpose elements were added above (1-20).
        return hospital
    }

    private func makeCornerPillar(height: Double) -> SCNNode {
        let geo = SCNBox(width: 0.4, height: CGFloat(height), length: 0.4, chamferRadius: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.7, alpha: 1.0)
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    private func makeWindowGrid(width: CGFloat, height: CGFloat) -> SCNNode {
        let geo = SCNPlane(width: width - 0.4, height: height - 0.4)
        let mat = SCNMaterial()
        mat.diffuse.contents = makeWindowGridImage()
        mat.lightingModel = .constant
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    private func makeWindowGridImage() -> UIImage {
        let size = CGSize(width: 128, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.86, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let cols = 6, rows = 14
            let cw = size.width / CGFloat(cols)
            let rh = size.height / CGFloat(rows)
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(x: CGFloat(c) * cw + 2, y: CGFloat(r) * rh + 2, width: cw - 4, height: rh - 4)
                    UIColor(red: 0.35, green: 0.55, blue: 0.7, alpha: 0.85).setFill()
                    ctx.fill(rect)
                }
            }
        }
    }

    private func makeCrossImage() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 24, y: 6, width: 16, height: 52))
            ctx.fill(CGRect(x: 6, y: 24, width: 52, height: 16))
        }
    }

    // MARK: - Clinic / dashboard anchor node

    private func buildClinicAnchorNode() {
        clinicNode = SCNNode()
        clinicNode.position = SCNVector3(0, 5, 6)
        scene.rootNode.addChildNode(clinicNode)
    }

    // MARK: - Time of day (Day / Afternoon / Eve)

    func setTimeOfDay(_ time: TimeOfDay) {
        guard let skyMat = skyNode.geometry?.firstMaterial else { return }

        switch time {
        case .day:
            skyMat.diffuse.contents = makeSkyGradient(top: UIColor(red: 0.35, green: 0.65, blue: 0.98, alpha: 1),
                                                        bottom: UIColor(red: 0.78, green: 0.9, blue: 1.0, alpha: 1))
            keyLight.light?.color = UIColor(white: 1.0, alpha: 1.0)
            keyLight.light?.intensity = 1200
            ambientLight.light?.color = UIColor(white: 0.55, alpha: 1.0)
            sunNode?.isHidden = false
            sunNode?.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 1)
            moonNode?.isHidden = true
            sunNode?.position = SCNVector3(30, 60, -130)
            setCloudColor(UIColor.white, opacity: 0.95)
            setWindowGlow(intensity: 0.0)
            setCrossGlow(on: false)

        case .afternoon:
            skyMat.diffuse.contents = makeSkyGradient(top: UIColor(red: 0.98, green: 0.55, blue: 0.35, alpha: 1),
                                                        bottom: UIColor(red: 1.0, green: 0.78, blue: 0.5, alpha: 1))
            keyLight.light?.color = UIColor(red: 1.0, green: 0.75, blue: 0.5, alpha: 1)
            keyLight.light?.intensity = 900
            ambientLight.light?.color = UIColor(red: 0.5, green: 0.4, blue: 0.4, alpha: 1)
            sunNode?.isHidden = false
            sunNode?.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
            moonNode?.isHidden = true
            sunNode?.position = SCNVector3(70, 22, -130)
            setCloudColor(UIColor(red: 1.0, green: 0.75, blue: 0.6, alpha: 1), opacity: 0.9)
            setWindowGlow(intensity: 0.15)
            setCrossGlow(on: false)

        case .eve:
            skyMat.diffuse.contents = makeSkyGradient(top: UIColor(red: 0.05, green: 0.06, blue: 0.18, alpha: 1),
                                                        bottom: UIColor(red: 0.18, green: 0.12, blue: 0.32, alpha: 1))
            keyLight.light?.color = UIColor(red: 0.5, green: 0.55, blue: 0.85, alpha: 1)
            keyLight.light?.intensity = 250
            ambientLight.light?.color = UIColor(white: 0.18, alpha: 1.0)
            sunNode?.isHidden = true
            moonNode?.isHidden = false
            setCloudColor(UIColor(red: 0.55, green: 0.58, blue: 0.72, alpha: 1), opacity: 0.55)
            setWindowGlow(intensity: 1.0)
            setCrossGlow(on: true)
        }
    }

    private func setCloudColor(_ color: UIColor, opacity: CGFloat) {
        for cloud in cloudNodes {
            for puff in cloud.childNodes {
                puff.geometry?.firstMaterial?.diffuse.contents = color
                puff.geometry?.firstMaterial?.transparency = opacity
            }
        }
    }

    private func setWindowGlow(intensity: CGFloat) {
        for mat in hospitalWindowMaterials {
            mat.emission.contents = UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1.0)
            mat.emission.intensity = intensity
        }
    }

    private func setCrossGlow(on: Bool) {
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "crossGlow" {
                node.geometry?.firstMaterial?.transparency = on ? 0.85 : 0.0
            }
            if node.name == "bayLight" {
                node.geometry?.firstMaterial?.emission.intensity = on ? 2.0 : 0.6
            }
        }
    }

    private func makeSkyGradient(top: UIColor, bottom: UIColor) -> UIImage {
        let size = CGSize(width: 4, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            ctx.cgContext.drawLinearGradient(gradient,
                                              start: CGPoint(x: 0, y: 0),
                                              end: CGPoint(x: 0, y: size.height),
                                              options: [])
        }
    }
}
