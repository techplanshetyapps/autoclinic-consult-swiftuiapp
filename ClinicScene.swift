import SceneKit
import UIKit
 
enum TimeOfDay: String, CaseIterable, Identifiable {
    case day = "Day"
    case afternoon = "Afternoon"
    case eve = "Eve"
    var id: String { rawValue }
 
    var panoramaAssetName: String {
        switch self {
        case .day: return "PanoramaDay"
        case .afternoon: return "PanoramaAfternoon"
        case .eve: return "PanoramaEve"
        }
    }
}

struct HospitalItem: Codable {
    let id: String
    let title: String
}

struct HospitalData: Codable {
    let hospitals: [HospitalItem]
}

final class ClinicScene {
 
    private(set) var hospitalTitles: [String: String] = [:]

        func loadHospitalTitles() {
            guard let url = Bundle.main.url(forResource: "HospitalTitles", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(HospitalData.self, from: data) else {
                print("Failed to load or parse HospitalTitles.json")
                return
            }
            
            for hospital in decoded.hospitals {
                hospitalTitles[hospital.id] = hospital.title
            }
        }
    
    
    
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private(set) var clinicNode = SCNNode()
    private var skydomeNode = SCNNode()
    private var hospitalWindowMaterials: [SCNMaterial] = []
    private var keyLight = SCNNode()
    private var ambientLight = SCNNode()
    private var rimLight = SCNNode()
 
    private var sunGroupNode = SCNNode()
    private var moonNode = SCNNode()
    private var starsNode = SCNNode()
    private var cloudClusterNodes: [SCNNode] = []
    private let afternoonCloudCount = 9
    private let dayCloudCount = 3
 
    init() {
        loadHospitalTitles()
        buildCamera()
        buildLights()
        buildPanoramaSkydome()
        buildSkyObjects()
        buildGround()
        buildHospitalNeighborhood()
        buildClinicAnchorNode()
        setTimeOfDay(.day)
    }
    
    private func buildCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 55
        camera.zNear = 0.1
        camera.zFar = 900
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 5, 16)
        cameraNode.eulerAngles = SCNVector3(-0.1, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }
 
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
 
    private func buildPanoramaSkydome() {
        let domeGeometry = SCNSphere(radius: 400)
        domeGeometry.segmentCount = 48
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.diffuse.contents = panoramaImage(for: .day)
        domeGeometry.materials = [material]
 
        skydomeNode = SCNNode(geometry: domeGeometry)
        skydomeNode.scale = SCNVector3(-1, 1, 1)
        skydomeNode.position = SCNVector3(0, 0, 0)
        skydomeNode.renderingOrder = -1000
        scene.rootNode.addChildNode(skydomeNode)
    }
 
    private func panoramaImage(for time: TimeOfDay) -> UIImage {
        if let image = UIImage(named: time.panoramaAssetName) {
            return image
        }
        switch time {
        case .day:
            return fallbackGradient(top: UIColor(red: 0.30, green: 0.62, blue: 0.98, alpha: 1),
                                     bottom: UIColor(red: 0.80, green: 0.92, blue: 1.0, alpha: 1))
        case .afternoon:
            return fallbackGradient(top: UIColor(red: 0.97, green: 0.52, blue: 0.28, alpha: 1),
                                     bottom: UIColor(red: 1.0, green: 0.80, blue: 0.52, alpha: 1))
        case .eve:
            return fallbackGradient(top: UIColor(red: 0.04, green: 0.05, blue: 0.16, alpha: 1),
                                     bottom: UIColor(red: 0.16, green: 0.11, blue: 0.30, alpha: 1))
        }
    }
 
    private func fallbackGradient(top: UIColor, bottom: UIColor) -> UIImage {
        let size = CGSize(width: 4, height: 512)
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
 
 
    private func buildSkyObjects() {
        buildSun()
        buildClouds()
        buildMoon()
        buildStars()
    }
 
    private func buildSun() {
        let sunGeo = SCNSphere(radius: 7)
        let sunMat = SCNMaterial()
        sunMat.lightingModel = .constant
        sunMat.diffuse.contents = UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 1)
        sunMat.emission.contents = UIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1)
        sunGeo.materials = [sunMat]
        
        let sunDisc = SCNNode(geometry: sunGeo)
        sunDisc.renderingOrder = 0

        let beamsContainer = SCNNode()
        beamsContainer.renderingOrder = 10
        
        let beamCount = 10
        for i in 0..<beamCount {
            let beam = makeBeamQuad()
            beam.eulerAngles = SCNVector3(0, 0, Double(i) * (2 * .pi / Double(beamCount)))
            beamsContainer.addChildNode(beam)
        }

        sunGroupNode.addChildNode(sunDisc)
        sunGroupNode.addChildNode(beamsContainer)
        sunGroupNode.constraints = [SCNBillboardConstraint()]
        sunGroupNode.position = SCNVector3(50, 90, -260)
        scene.rootNode.addChildNode(sunGroupNode)
    }

    private func makeBeamQuad() -> SCNNode {
        let geo = SCNPlane(width: 3.2, height: 34)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = radialBeamImage()
        mat.blendMode = .add
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(12, 17, -45)
        node.pivot = SCNMatrix4MakeTranslation(0, 17, 0)
        return node
    }
 
    private func radialBeamImage() -> UIImage {
        let size = CGSize(width: 64, height: 512)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [
                UIColor(white: 1.0, alpha: 0.85).cgColor,
                UIColor(white: 1.0, alpha: 0.15).cgColor,
                UIColor(white: 1.0, alpha: 0.0).cgColor,
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.4, 1]) else { return }
            ctx.cgContext.drawLinearGradient(gradient,
                                              start: CGPoint(x: size.width / 2, y: 0),
                                              end: CGPoint(x: size.width / 2, y: size.height),
                                              options: [])
        }
    }
 
    private func buildClouds() {
        let totalClouds = afternoonCloudCount
        for i in 0..<totalClouds {
            let cluster = makeCloudCluster()
            let x = Double(i - totalClouds / 2) * 22 + Double.random(in: -8...8)
            let y = 55 + Double.random(in: -6...14)
            let z = -220 + Double.random(in: -20...20)
            cluster.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(cluster)
            cloudClusterNodes.append(cluster)
        }
    }
 
    private func makeCloudCluster() -> SCNNode {
        let cluster = SCNNode()
        for p in 0..<4 {
            let radius = CGFloat.random(in: 3.5...6.5)
            let geo = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = UIColor.white
            geo.materials = [mat]
            let puff = SCNNode(geometry: geo)
            puff.position = SCNVector3(Double(p) * 4.0 - 6.0, Double.random(in: -0.8...0.8), Double.random(in: -1...1))
            puff.scale = SCNVector3(1.0, 0.55, 1.0)
            cluster.addChildNode(puff)
        }
        return cluster
    }
 
    private func buildMoon() {
        let moonGeo = SCNSphere(radius: 9)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = moonSurfaceImage()
        moonGeo.materials = [mat]
        moonNode = SCNNode(geometry: moonGeo)
        moonNode.position = SCNVector3(-60, 95, -260)
        scene.rootNode.addChildNode(moonNode)
    }
 
    private func moonSurfaceImage() -> UIImage {
        let size = CGSize(width: 256, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.93, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let craterColor = UIColor(white: 0.80, alpha: 1.0)
            craterColor.setFill()
            let craters: [(CGFloat, CGFloat, CGFloat)] = [
                (70, 60, 22), (150, 90, 16), (190, 180, 26), (90, 190, 14), (140, 150, 10),
            ]
            for (cx, cy, r) in craters {
                ctx.cgContext.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }
        }
    }
 
    /// A scattered field of small twinkling stars, visible only at Eve.
    private func buildStars() {
        starsNode = SCNNode()
        let starMat = SCNMaterial()
        starMat.lightingModel = .constant
        starMat.diffuse.contents = UIColor.white
        starMat.emission.contents = UIColor.white
 
        for _ in 0..<140 {
            let geo = SCNSphere(radius: CGFloat.random(in: 0.25...0.7))
            geo.materials = [starMat]
            let star = SCNNode(geometry: geo)
 
            let radius: Double = 350
            let theta = Double.random(in: 0...(2 * .pi))
            let phi = Double.random(in: 0...(.pi / 2.4))
            star.position = SCNVector3(
                radius * sin(phi) * cos(theta),
                radius * cos(phi),
                radius * sin(phi) * sin(theta) - 100
            )
 
            let fadeOut = SCNAction.fadeOpacity(to: CGFloat.random(in: 0.3...0.6), duration: Double.random(in: 1.0...2.5))
            let fadeIn = SCNAction.fadeOpacity(to: 1.0, duration: Double.random(in: 1.0...2.5))
            star.runAction(.repeatForever(.sequence([fadeOut, fadeIn])))
 
            starsNode.addChildNode(star)
        }
        scene.rootNode.addChildNode(starsNode)
    }
 
 
    private func buildGround() {
        let ground = SCNFloor()
        ground.reflectivity = 0.02
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.30, green: 0.34, blue: 0.28, alpha: 1.0) // soft grass-adjacent tone
        mat.roughness.contents = 0.95
        ground.materials = [mat]
        let node = SCNNode(geometry: ground)
        node.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(node)
    }
 
    private struct Architecture {
        let mainW: CGFloat
        let mainD: CGFloat
        let mainH: CGFloat
        let hasSecondWing: Bool
        let secW: CGFloat
        let secD: CGFloat
        let secH: CGFloat
        let secOffsetX: CGFloat
        let secOffsetZ: CGFloat
        let hasBalcony: Bool
        let facade: UIColor
        let trim: UIColor
        let roof: UIColor
    }
 
    private let architectures: [Architecture] = [
        Architecture(mainW: 14, mainD: 9, mainH: 6.5, hasSecondWing: true,  secW: 7, secD: 6, secH: 4.5,
                     secOffsetX: 9, secOffsetZ: 1.5, hasBalcony: true,
                     facade: UIColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1), // cream
                     trim: UIColor(red: 0.55, green: 0.42, blue: 0.30, alpha: 1),
                     roof: UIColor(red: 0.35, green: 0.30, blue: 0.28, alpha: 1)),
        Architecture(mainW: 11, mainD: 11, mainH: 5.0, hasSecondWing: false, secW: 0, secD: 0, secH: 0,
                     secOffsetX: 0, secOffsetZ: 0, hasBalcony: false,
                     facade: UIColor(red: 0.80, green: 0.88, blue: 0.94, alpha: 1), // pale blue
                     trim: UIColor(white: 0.95, alpha: 1),
                     roof: UIColor(red: 0.20, green: 0.24, blue: 0.30, alpha: 1)),
        Architecture(mainW: 16, mainD: 7, mainH: 5.5, hasSecondWing: true,  secW: 6, secD: 8, secH: 5.5,
                     secOffsetX: -10, secOffsetZ: 2.5, hasBalcony: true,
                     facade: UIColor(red: 0.72, green: 0.80, blue: 0.66, alpha: 1), // sage green
                     trim: UIColor(red: 0.98, green: 0.98, blue: 0.95, alpha: 1),
                     roof: UIColor(red: 0.30, green: 0.34, blue: 0.26, alpha: 1)),
        Architecture(mainW: 10, mainD: 10, mainH: 7.0, hasSecondWing: true,  secW: 10, secD: 4, secH: 4.0,
                     secOffsetX: 0, secOffsetZ: -6.5, hasBalcony: false,
                     facade: UIColor(red: 0.85, green: 0.55, blue: 0.42, alpha: 1), // terracotta
                     trim: UIColor(white: 0.98, alpha: 1),
                     roof: UIColor(red: 0.45, green: 0.28, blue: 0.20, alpha: 1)),
        Architecture(mainW: 13, mainD: 8, mainH: 4.5, hasSecondWing: false, secW: 0, secD: 0, secH: 0,
                     secOffsetX: 0, secOffsetZ: 0, hasBalcony: true,
                     facade: UIColor(red: 0.82, green: 0.82, blue: 0.83, alpha: 1), // light grey
                     trim: UIColor(red: 0.25, green: 0.40, blue: 0.55, alpha: 1),
                     roof: UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1)),
        Architecture(mainW: 9, mainD: 9, mainH: 6.0, hasSecondWing: true,  secW: 9, secD: 5, secH: 4.5,
                     secOffsetX: 6.5, secOffsetZ: -6, hasBalcony: true,
                     facade: UIColor(red: 0.96, green: 0.87, blue: 0.55, alpha: 1), // soft yellow
                     trim: UIColor(red: 0.55, green: 0.40, blue: 0.22, alpha: 1),
                     roof: UIColor(red: 0.42, green: 0.36, blue: 0.20, alpha: 1)),
    ]
 
    private func buildHospitalNeighborhood() {
        let positions: [(x: Double, z: Double)] = [
            (-30, -32), (-14, -42), (2, -30), (18, -40), (32, -28), (-42, -22)
        ]
        
        for (i, p) in positions.enumerated() {
            let arch = architectures[i % architectures.count]
            let hospital = makeHospital(architecture: arch, seed: i)
            hospital.position = SCNVector3(p.x, 0, p.z)
            hospital.eulerAngles = SCNVector3(0, Double(i) * 0.35, 0)
            
            let hospitalID = String(format: "hospital%02d", i + 1)
            hospital.name = hospitalID
            
            if let title = hospitalTitles[hospitalID] {
                hospital.setValue(title, forKey: "title")
            }
            
            for child in hospital.childNodes {
                child.name = hospitalID
            }
            
            scene.rootNode.addChildNode(hospital)
        }
    }
 
    private func makeHospital(architecture a: Architecture, seed: Int) -> SCNNode {
        let hospital = SCNNode()
 
        func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, color: UIColor, chamfer: CGFloat = 0.08) -> SCNNode {
            let geo = SCNBox(width: w, height: h, length: d, chamferRadius: chamfer)
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.roughness.contents = 0.8
            geo.materials = [mat]
            return SCNNode(geometry: geo)
        }
        func cyl(_ r: CGFloat, _ h: CGFloat, color: UIColor) -> SCNNode {
            let geo = SCNCylinder(radius: r, height: h)
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            geo.materials = [mat]
            return SCNNode(geometry: geo)
        }
        func plane(_ w: CGFloat, _ h: CGFloat, color: UIColor, emissive: Bool = false) -> SCNNode {
            let geo = SCNPlane(width: w, height: h)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = emissive ? UIColor.clear : color
            if emissive { mat.emission.contents = color }
            geo.materials = [mat]
            return SCNNode(geometry: geo)
        }
 
        let mainH = a.mainH
 
        // 1. Main wing body
        let mainBody = box(a.mainW, mainH, a.mainD, color: a.facade)
        mainBody.position = SCNVector3(0, Double(mainH) / 2, 0)
        hospital.addChildNode(mainBody)
 
        let secH = a.hasSecondWing ? a.secH : 2.2
        let secW = a.hasSecondWing ? a.secW : 2.0
        let secD = a.hasSecondWing ? a.secD : 2.0
        let secColor = a.hasSecondWing ? a.facade : a.trim
        let secondaryBody = box(secW, secH, secD, color: secColor)
        secondaryBody.position = SCNVector3(Double(a.secOffsetX), Double(secH) / 2, Double(a.secOffsetZ))
        hospital.addChildNode(secondaryBody)
 
        // 3. Connecting corridor block
        let corridorLength: CGFloat = max(1.5, abs(a.secOffsetX) - a.mainW / 2 - secW / 2 + 1.0)
        let corridor = box(corridorLength, 2.6, 2.2, color: a.trim)
        corridor.position = SCNVector3(Double(a.secOffsetX) * 0.5, 1.3, Double(a.secOffsetZ) * 0.5)
        hospital.addChildNode(corridor)
 
        // 4. Roof cap — main wing
        let roofMain = box(a.mainW + 0.4, 0.3, a.mainD + 0.4, color: a.roof)
        roofMain.position = SCNVector3(0, Double(mainH) + 0.15, 0)
        hospital.addChildNode(roofMain)
 
        // 5. Roof cap — secondary wing
        let roofSec = box(secW + 0.4, 0.25, secD + 0.4, color: a.roof)
        roofSec.position = SCNVector3(Double(a.secOffsetX), Double(secH) + 0.13, Double(a.secOffsetZ))
        hospital.addChildNode(roofSec)
 
        // 6. Roof parapet trim — main
        let parapetMain = box(a.mainW + 0.4, 0.5, 0.2, color: a.trim)
        parapetMain.position = SCNVector3(0, Double(mainH) + 0.4, Double(a.mainD) / 2 + 0.1)
        hospital.addChildNode(parapetMain)
 
        // 7. Roof parapet trim — secondary
        let parapetSec = box(secW + 0.4, 0.4, 0.15, color: a.trim)
        parapetSec.position = SCNVector3(Double(a.secOffsetX), Double(secH) + 0.35, Double(a.secOffsetZ) + Double(secD) / 2 + 0.08)
        hospital.addChildNode(parapetSec)
 
        // 8. Window grid — main wing front
        let winMainFront = windowGrid(width: a.mainW - 1.0, height: mainH - 1.2, rows: max(2, Int(mainH / 1.6)))
        winMainFront.position = SCNVector3(0, Double(mainH) / 2, Double(a.mainD) / 2 + 0.03)
        hospital.addChildNode(winMainFront)
        hospitalWindowMaterials.append(winMainFront.geometry!.materials[0])
 
        // 9. Window grid — main wing side
        let winMainSide = windowGrid(width: a.mainD - 1.0, height: mainH - 1.2, rows: max(2, Int(mainH / 1.6)))
        winMainSide.eulerAngles = SCNVector3(0, Double.pi / 2, 0)
        winMainSide.position = SCNVector3(Double(a.mainW) / 2 + 0.03, Double(mainH) / 2, 0)
        hospital.addChildNode(winMainSide)
        hospitalWindowMaterials.append(winMainSide.geometry!.materials[0])
 
        // 10. Window grid — secondary wing front
        let winSecFront = windowGrid(width: max(1.0, secW - 0.8), height: max(1.0, secH - 0.8), rows: 2)
        winSecFront.position = SCNVector3(Double(a.secOffsetX), Double(secH) / 2, Double(a.secOffsetZ) + Double(secD) / 2 + 0.03)
        hospital.addChildNode(winSecFront)
        hospitalWindowMaterials.append(winSecFront.geometry!.materials[0])
 
        // 11. Window grid — secondary wing side
        let winSecSide = windowGrid(width: max(1.0, secD - 0.8), height: max(1.0, secH - 0.8), rows: 2)
        winSecSide.eulerAngles = SCNVector3(0, Double.pi / 2, 0)
        winSecSide.position = SCNVector3(Double(a.secOffsetX) + Double(secW) / 2 + 0.03, Double(secH) / 2, Double(a.secOffsetZ))
        hospital.addChildNode(winSecSide)
        hospitalWindowMaterials.append(winSecSide.geometry!.materials[0])
 
        // 12. Floor trim band — main wing
        let floorTrimMain = box(a.mainW + 0.15, 0.2, a.mainD + 0.15, color: a.trim)
        floorTrimMain.position = SCNVector3(0, Double(mainH) * 0.5, 0)
        hospital.addChildNode(floorTrimMain)
 
        // 13. Floor trim band — secondary wing
        let floorTrimSec = box(secW + 0.15, 0.15, secD + 0.15, color: a.trim)
        floorTrimSec.position = SCNVector3(Double(a.secOffsetX), Double(secH) * 0.5, Double(a.secOffsetZ))
        hospital.addChildNode(floorTrimSec)
 
        // 14-17. Corner pillars (front-left, front-right, back-left, back-right)
        let pillarPositions: [(Double, Double)] = [
            (-Double(a.mainW) / 2, Double(a.mainD) / 2),
            (Double(a.mainW) / 2, Double(a.mainD) / 2),
            (-Double(a.mainW) / 2, -Double(a.mainD) / 2),
            (Double(a.mainW) / 2, -Double(a.mainD) / 2),
        ]
        for (x, z) in pillarPositions {
            let pillar = box(0.35, mainH, 0.35, color: a.trim)
            pillar.position = SCNVector3(x, Double(mainH) / 2, z)
            hospital.addChildNode(pillar)
        }
 
        // 18. Rooftop AC condenser unit 1
        let ac1 = box(1.2, 0.8, 1.2, color: UIColor(white: 0.5, alpha: 1))
        ac1.position = SCNVector3(-Double(a.mainW) * 0.2, Double(mainH) + 0.7, Double(a.mainD) * 0.15)
        hospital.addChildNode(ac1)
 
        // 19. Rooftop AC condenser unit 2
        let ac2 = box(0.9, 0.6, 0.9, color: UIColor(white: 0.45, alpha: 1))
        ac2.position = SCNVector3(Double(a.mainW) * 0.18, Double(mainH) + 0.6, -Double(a.mainD) * 0.2)
        hospital.addChildNode(ac2)
 
        // 20. Rooftop vent stack 1
        let vent1 = cyl(0.15, 1.0, color: UIColor(white: 0.35, alpha: 1))
        vent1.position = SCNVector3(-Double(a.mainW) * 0.3, Double(mainH) + 1.0, -Double(a.mainD) * 0.25)
        hospital.addChildNode(vent1)
 
        // 21. Rooftop vent stack 2
        let vent2 = cyl(0.12, 0.8, color: UIColor(white: 0.35, alpha: 1))
        vent2.position = SCNVector3(Double(a.mainW) * 0.3, Double(mainH) + 0.9, Double(a.mainD) * 0.28)
        hospital.addChildNode(vent2)
 
        // 22. Rooftop skylight
        let skylight = box(1.6, 0.2, 1.0, color: UIColor(red: 0.55, green: 0.75, blue: 0.9, alpha: 0.75))
        skylight.position = SCNVector3(0, Double(mainH) + 0.4, 0)
        hospital.addChildNode(skylight)
 
        // 23. Rooftop water tank
        let tank = cyl(0.6, 1.3, color: UIColor(red: 0.5, green: 0.38, blue: 0.28, alpha: 1))
        tank.position = SCNVector3(Double(a.mainW) * 0.05, Double(mainH) + 1.05, Double(a.mainD) * 0.32)
        hospital.addChildNode(tank)
 
        // 24. Entrance canopy
        let canopy = box(4.2, 0.22, 2.0, color: a.trim)
        canopy.position = SCNVector3(0, 2.6, Double(a.mainD) / 2 + 1.0)
        hospital.addChildNode(canopy)
 
        // 25. Entrance column (left)
        let colL = cyl(0.14, 2.6, color: a.trim)
        colL.position = SCNVector3(-1.7, 1.3, Double(a.mainD) / 2 + 1.9)
        hospital.addChildNode(colL)
 
        // 26. Entrance column (right)
        let colR = cyl(0.14, 2.6, color: a.trim)
        colR.position = SCNVector3(1.7, 1.3, Double(a.mainD) / 2 + 1.9)
        hospital.addChildNode(colR)
 
        // 27. Entrance double door — left leaf
        let doorL = box(1.0, 2.3, 0.06, color: UIColor(red: 0.5, green: 0.72, blue: 0.88, alpha: 0.65))
        doorL.position = SCNVector3(-0.52, 1.15, Double(a.mainD) / 2 + 0.06)
        hospital.addChildNode(doorL)
 
        // 28. Entrance double door — right leaf
        let doorR = box(1.0, 2.3, 0.06, color: UIColor(red: 0.5, green: 0.72, blue: 0.88, alpha: 0.65))
        doorR.position = SCNVector3(0.52, 1.15, Double(a.mainD) / 2 + 0.06)
        hospital.addChildNode(doorR)
 
        // 29. Reception signage plaque
        let plaque = plane(1.6, 0.5, color: UIColor(white: 0.98, alpha: 1))
        plaque.position = SCNVector3(-Double(a.mainW) * 0.25, 2.2, Double(a.mainD) / 2 + 0.05)
        hospital.addChildNode(plaque)
 
        // 30. Hospital name plaque backing
        let plaqueBacking = box(1.7, 0.55, 0.05, color: a.trim)
        plaqueBacking.position = SCNVector3(-Double(a.mainW) * 0.25, 2.2, Double(a.mainD) / 2 + 0.02)
        hospital.addChildNode(plaqueBacking)
 
        // 31. Red cross sign
        let cross = plane(1.3, 1.3, color: UIColor.white)
        cross.geometry?.firstMaterial?.diffuse.contents = crossImage()
        cross.position = SCNVector3(Double(a.mainW) * 0.28, mainH * 0.7, Double(a.mainD) / 2 + 0.05)
        hospital.addChildNode(cross)
 
        // 32. Red cross glow panel
        let crossGlow = plane(1.6, 1.6, color: UIColor.red, emissive: true)
        crossGlow.geometry?.firstMaterial?.transparency = 0.0
        crossGlow.position = SCNVector3(Double(a.mainW) * 0.28, mainH * 0.7, Double(a.mainD) / 2 + 0.03)
        crossGlow.name = "crossGlow"
        hospital.addChildNode(crossGlow)
 
        // 33. Ambulance bay roller door
        let bayDoor = box(2.6, 2.4, 0.1, color: UIColor(white: 0.55, alpha: 1))
        bayDoor.position = SCNVector3(Double(a.mainW) * 0.42, 1.2, Double(a.mainD) / 2 + 0.05)
        hospital.addChildNode(bayDoor)
 
        // 34. Ambulance bay warning light
        let bayLight = cyl(0.14, 0.14, color: UIColor.orange)
        bayLight.geometry?.firstMaterial?.emission.contents = UIColor.orange
        bayLight.position = SCNVector3(Double(a.mainW) * 0.42, 2.5, Double(a.mainD) / 2 + 0.1)
        bayLight.name = "bayLight"
        hospital.addChildNode(bayLight)
 
        // 35. Ambulance ramp
        let ramp = box(3.0, 0.15, 3.0, color: UIColor(white: 0.6, alpha: 1))
        ramp.position = SCNVector3(Double(a.mainW) * 0.42, 0.08, Double(a.mainD) / 2 + 2.2)
        hospital.addChildNode(ramp)
 
        // 36. Wheelchair ramp rail
        let rampRail = box(0.06, 0.6, 3.0, color: UIColor(white: 0.75, alpha: 1))
        rampRail.position = SCNVector3(Double(a.mainW) * 0.42 + 1.4, 0.35, Double(a.mainD) / 2 + 2.2)
        hospital.addChildNode(rampRail)
 
        // 37. Ground-floor window awning (main wing)
        let awningMain = box(2.4, 0.1, 0.6, color: a.roof)
        awningMain.position = SCNVector3(-Double(a.mainW) * 0.15, 2.0, Double(a.mainD) / 2 + 0.4)
        hospital.addChildNode(awningMain)
 
        // 38. Ground-floor window awning (secondary wing)
        let awningSec = box(1.4, 0.08, 0.5, color: a.roof)
        awningSec.position = SCNVector3(Double(a.secOffsetX), 1.4, Double(a.secOffsetZ) + Double(secD) / 2 + 0.35)
        hospital.addChildNode(awningSec)
 
        // 39. Balcony ledge (second floor)
        let balconyLedge = box(a.hasBalcony ? a.mainW * 0.5 : 1.0, 0.15, 0.8, color: a.trim)
        balconyLedge.position = SCNVector3(0, mainH * 0.62, Double(a.mainD) / 2 + 0.5)
        hospital.addChildNode(balconyLedge)
 
        // 40. Balcony railing
        let balconyRail = box(a.hasBalcony ? a.mainW * 0.5 : 1.0, 0.5, 0.06, color: a.trim)
        balconyRail.position = SCNVector3(0, mainH * 0.62 + 0.3, Double(a.mainD) / 2 + 0.86)
        hospital.addChildNode(balconyRail)
 
        // 41. Ground planter box (left)
        let planterL = box(1.2, 0.45, 0.7, color: UIColor(red: 0.32, green: 0.24, blue: 0.16, alpha: 1))
        planterL.position = SCNVector3(-Double(a.mainW) * 0.4, 0.22, Double(a.mainD) / 2 + 1.3)
        hospital.addChildNode(planterL)
 
        // 42. Ground planter box (right)
        let planterR = box(1.2, 0.45, 0.7, color: UIColor(red: 0.32, green: 0.24, blue: 0.16, alpha: 1))
        planterR.position = SCNVector3(Double(a.mainW) * 0.4, 0.22, Double(a.mainD) / 2 + 1.3)
        hospital.addChildNode(planterR)
 
        // 43. Exterior bench
        let bench = box(1.4, 0.35, 0.4, color: UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1))
        bench.position = SCNVector3(-Double(a.mainW) * 0.15, 0.2, Double(a.mainD) / 2 + 2.6)
        hospital.addChildNode(bench)
 
        // 44. Bike rack
        let bikeRack = box(1.0, 0.4, 0.1, color: UIColor(white: 0.4, alpha: 1))
        bikeRack.position = SCNVector3(Double(a.mainW) * 0.15, 0.2, Double(a.mainD) / 2 + 2.6)
        hospital.addChildNode(bikeRack)
 
        // 45. Flagpole
        let flagpole = cyl(0.05, 4.0, color: UIColor(white: 0.7, alpha: 1))
        flagpole.position = SCNVector3(-Double(a.mainW) * 0.5 - 1.0, 2.0, Double(a.mainD) / 2 + 1.0)
        hospital.addChildNode(flagpole)
 
        // 46. Flag
        let flag = plane(0.6, 0.4, color: UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1))
        flag.position = SCNVector3(-Double(a.mainW) * 0.5 - 0.7, 3.6, Double(a.mainD) / 2 + 1.0)
        hospital.addChildNode(flag)
 
        // 47. Exterior lamp post (left)
        let lampL = cyl(0.06, 2.4, color: UIColor(white: 0.3, alpha: 1))
        lampL.position = SCNVector3(-Double(a.mainW) * 0.5 - 1.5, 1.2, Double(a.mainD) / 2 + 3.5)
        hospital.addChildNode(lampL)
 
        // 48. Exterior lamp post (right)
        let lampR = cyl(0.06, 2.4, color: UIColor(white: 0.3, alpha: 1))
        lampR.position = SCNVector3(Double(a.mainW) * 0.5 + 1.5, 1.2, Double(a.mainD) / 2 + 3.5)
        hospital.addChildNode(lampR)
 
        // 49. Perimeter low wall segment
        let lowWall = box(a.mainW + 4.0, 0.4, 0.2, color: a.trim)
        lowWall.position = SCNVector3(0, 0.2, Double(a.mainD) / 2 + 4.2)
        hospital.addChildNode(lowWall)
 
        // 50. Base pedestal / foundation lip
        let base = box(a.mainW + 1.0, 0.4, a.mainD + 1.0, color: UIColor(white: 0.6, alpha: 1))
        base.position = SCNVector3(0, 0.2, 0)
        hospital.addChildNode(base)
 
        // sanity: exactly 50 elements were added above (1-50).
        return hospital
    }
 
    private func windowGrid(width: CGFloat, height: CGFloat, rows: Int) -> SCNNode {
        let w = max(width, 1.0)
        let h = max(height, 1.0)
        let geo = SCNPlane(width: w, height: h)
        let mat = SCNMaterial()
        mat.diffuse.contents = windowGridImage(rows: rows)
        mat.lightingModel = .constant
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }
 
    private func windowGridImage(rows: Int) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.88, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let cols = 5
            let cw = size.width / CGFloat(cols)
            let rh = size.height / CGFloat(max(rows, 1))
            for r in 0..<max(rows, 1) {
                for c in 0..<cols {
                    let rect = CGRect(x: CGFloat(c) * cw + 3, y: CGFloat(r) * rh + 3, width: cw - 6, height: rh - 6)
                    UIColor(red: 0.35, green: 0.55, blue: 0.7, alpha: 0.85).setFill()
                    ctx.fill(rect)
                }
            }
        }
    }
 
    private func crossImage() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 24, y: 6, width: 16, height: 52))
            ctx.fill(CGRect(x: 6, y: 24, width: 52, height: 16))
        }
    }
 
    private func buildClinicAnchorNode() {
        clinicNode = SCNNode()
        clinicNode.name = "clinicAnchor"
        clinicNode.position = SCNVector3(0, 5, 6)
        scene.rootNode.addChildNode(clinicNode)
    }
    
    func setTimeOfDay(_ time: TimeOfDay) {
        skydomeNode.geometry?.firstMaterial?.diffuse.contents = panoramaImage(for: time)
 
        switch time {
        case .day:
            keyLight.light?.color = UIColor(white: 1.0, alpha: 1.0)
            keyLight.light?.intensity = 1200
            ambientLight.light?.color = UIColor(white: 0.55, alpha: 1.0)
            setWindowGlow(intensity: 0.0)
            setCrossGlow(on: false)
 
            sunGroupNode.isHidden = false
            sunGroupNode.position = SCNVector3(50, 95, -260)
            tintSun(UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 1))
            moonNode.isHidden = true
            starsNode.isHidden = true
            setCloudVisibility(count: dayCloudCount, tint: UIColor.white)
 
        case .afternoon:
            keyLight.light?.color = UIColor(red: 1.0, green: 0.75, blue: 0.5, alpha: 1)
            keyLight.light?.intensity = 900
            ambientLight.light?.color = UIColor(red: 0.5, green: 0.4, blue: 0.4, alpha: 1)
            setWindowGlow(intensity: 0.15)
            setCrossGlow(on: false)
 
            sunGroupNode.isHidden = false
            sunGroupNode.position = SCNVector3(90, 45, -260)
            tintSun(UIColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1))
            moonNode.isHidden = true
            starsNode.isHidden = true
            setCloudVisibility(count: afternoonCloudCount, tint: UIColor(red: 1.0, green: 0.78, blue: 0.6, alpha: 1))
 
        case .eve:
            keyLight.light?.color = UIColor(red: 0.5, green: 0.55, blue: 0.85, alpha: 1)
            keyLight.light?.intensity = 250
            ambientLight.light?.color = UIColor(white: 0.18, alpha: 1.0)
            setWindowGlow(intensity: 1.0)
            setCrossGlow(on: true)
 
            sunGroupNode.isHidden = true
            moonNode.isHidden = false
            starsNode.isHidden = false
            setCloudVisibility(count: 0, tint: .white) // clear night, no clouds
        }
    }
 
    private func tintSun(_ color: UIColor) {
        // sunGroupNode's children: [beamsContainer, sunDisc]
        guard sunGroupNode.childNodes.count >= 2 else { return }
        sunGroupNode.childNodes[1].geometry?.firstMaterial?.diffuse.contents = color
        sunGroupNode.childNodes[1].geometry?.firstMaterial?.emission.contents = color
    }
 
    private func setCloudVisibility(count: Int, tint: UIColor) {
        for (i, cloud) in cloudClusterNodes.enumerated() {
            cloud.isHidden = i >= count
            for puff in cloud.childNodes {
                puff.geometry?.firstMaterial?.diffuse.contents = tint
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
}
