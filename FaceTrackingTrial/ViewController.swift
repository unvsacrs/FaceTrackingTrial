//
//  ViewController.swift
//  FaceTrackingTrial
//
//  Created by Yasushi Nozaki on 2020/06/05.
//  Copyright © 2020 Yasushi Nozaki. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import WebKit

extension SCNVector3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
}

func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(l.x - r.x, l.y - r.y, l.z - r.z)
}

extension Collection where Element == CGFloat, Index == Int {
    /// Return the mean of a list of CGFloat. Used with `recentVirtualObjectDistances`.
    var average: CGFloat? {
        guard !isEmpty else {
            return nil
        }
        
        let sum = reduce(CGFloat(0)) { current, next -> CGFloat in
            return current + next
        }
        
        return sum / CGFloat(count)
    }
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var eyePositionIndicatorView: UIView!
    @IBOutlet weak var eyePositionIndicatorCenterView: UIView!
    @IBOutlet weak var lookAtPositionXLabel: UILabel!
    @IBOutlet weak var lookAtPositionYLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!

    var faceNode: SCNNode = SCNNode()
    
    var eyeLNode: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.3)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()
    
    var eyeRNode: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.3)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()
    
    var lookAtTargetEyeLNode: SCNNode = SCNNode()
    var lookAtTargetEyeRNode: SCNNode = SCNNode()
    
    // actual physical size of iPhoneX screen
    //let phoneScreenSize = CGSize(width: 0.0623908297, height: 0.135096943231532)

    // actual point size of iPhoneX screen
    // let phoneScreenPointSize = CGSize(width: 375, height: 812)

    // actual physical size of iPadPro screen
    let phoneScreenSize = CGSize(width: 0.138757205, height: 0.198652402)

    // actual point size of iPadPro screen
    let phoneScreenPointSize = CGSize(width: 834, height: 1194)

    var virtualPhoneNode: SCNNode = SCNNode()
    
    var virtualScreenNode: SCNNode = {
        
        let screenGeometry = SCNPlane(width: 1, height: 1)
        screenGeometry.firstMaterial?.isDoubleSided = true
        screenGeometry.firstMaterial?.diffuse.contents = UIColor.green
        
        return SCNNode(geometry: screenGeometry)
    }()
    
    var eyeLookAtPositionXs: [CGFloat] = []
    
    var eyeLookAtPositionYs: [CGFloat] = []

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Design Elements
        eyePositionIndicatorView.layer.cornerRadius = eyePositionIndicatorView.bounds.width / 2
        sceneView.layer.cornerRadius = 28
        eyePositionIndicatorCenterView.layer.cornerRadius = 4
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // Setup Scenegraph
        sceneView.scene.rootNode.addChildNode(faceNode)
        sceneView.scene.rootNode.addChildNode(virtualPhoneNode)
        virtualPhoneNode.addChildNode(virtualScreenNode)
        faceNode.addChildNode(eyeLNode)
        faceNode.addChildNode(eyeRNode)
        eyeLNode.addChildNode(lookAtTargetEyeLNode)
        eyeRNode.addChildNode(lookAtTargetEyeRNode)
        
        // Set LookAtTargetEye at 2 meters away from the center of eyeballs to create segment vector
        lookAtTargetEyeLNode.position.z = 1
        lookAtTargetEyeRNode.position.z = 1
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        update(withFaceAnchor: faceAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        virtualPhoneNode.transform = (sceneView.pointOfView?.transform)!
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        update(withFaceAnchor: faceAnchor)
    }

    private static func getLookAtPoint(result: SCNHitTestResult, screenSize: CGSize, screenPointSize: CGSize, heightCompensation: CGFloat) -> CGPoint {
        let x = CGFloat(result.localCoordinates.x) / (screenSize.width / 2) * screenPointSize.width * 2.25
        let y = CGFloat(result.localCoordinates.y) / (screenSize.height / 2) * screenPointSize.height * 1.9
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - update(ARFaceAnchor)
    func update(withFaceAnchor anchor: ARFaceAnchor) {
        
        self.eyeRNode.simdTransform = anchor.rightEyeTransform
        self.eyeLNode.simdTransform = anchor.leftEyeTransform
        
        var eyeLLookAt = CGPoint()
        var eyeRLookAt = CGPoint()

        let heightCompensation: CGFloat = 459
        
        DispatchQueue.main.async {

            // Perform Hit test using the ray segments that are drawn by the center of the eyeballs to somewhere two meters away at direction of where users look at to the virtual plane that place at the same orientation of the phone screen
            
            let phoneScreenEyeRHitTestResults = self.virtualPhoneNode.hitTestWithSegment(from: self.lookAtTargetEyeRNode.worldPosition, to: self.eyeRNode.worldPosition, options: nil)
            
            let phoneScreenEyeLHitTestResults = self.virtualPhoneNode.hitTestWithSegment(from: self.lookAtTargetEyeLNode.worldPosition, to: self.eyeLNode.worldPosition, options: nil)

            if let result = phoneScreenEyeRHitTestResults.first {
                eyeRLookAt = ViewController.getLookAtPoint(result: result, screenSize: self.phoneScreenSize, screenPointSize: self.phoneScreenPointSize, heightCompensation: heightCompensation)
            }

            if let result = phoneScreenEyeLHitTestResults.first {
                eyeLLookAt = ViewController.getLookAtPoint(result: result, screenSize: self.phoneScreenSize, screenPointSize: self.phoneScreenPointSize, heightCompensation: heightCompensation)
            }

            // Add the latest position and keep up to 8 recent position to smooth with.
            let smoothThresholdNumber: Int = 10
            self.eyeLookAtPositionXs.append((eyeRLookAt.x + eyeLLookAt.x) / 2)
            self.eyeLookAtPositionYs.append(-(eyeRLookAt.y + eyeLLookAt.y) / 2)
            self.eyeLookAtPositionXs = Array(self.eyeLookAtPositionXs.suffix(smoothThresholdNumber))
            self.eyeLookAtPositionYs = Array(self.eyeLookAtPositionYs.suffix(smoothThresholdNumber))
            
            var smoothEyeLookAtPositionX = self.eyeLookAtPositionXs.average!
            var smoothEyeLookAtPositionY = self.eyeLookAtPositionYs.average!
            
            if smoothEyeLookAtPositionX < 0 - (self.phoneScreenPointSize.width / 2) {
               smoothEyeLookAtPositionX = 0 - (self.phoneScreenPointSize.width / 2)

            } else if smoothEyeLookAtPositionX > (self.phoneScreenPointSize.width / 2) {
                smoothEyeLookAtPositionX = self.phoneScreenPointSize.width / 2

            }
            
            if smoothEyeLookAtPositionY < 0 - (self.phoneScreenPointSize.height / 2) {
               smoothEyeLookAtPositionY = 0 - (self.phoneScreenPointSize.height / 2)

            } else if smoothEyeLookAtPositionY > (self.phoneScreenPointSize.height / 2 + heightCompensation) {
                smoothEyeLookAtPositionY = self.phoneScreenPointSize.height / 2 + heightCompensation

            }

            // update indicator position
            self.eyePositionIndicatorView.transform = CGAffineTransform(translationX: smoothEyeLookAtPositionX, y: smoothEyeLookAtPositionY)
            
            
            // update eye look at labels values
            self.lookAtPositionXLabel.text = "\(Int(round(smoothEyeLookAtPositionX + self.phoneScreenPointSize.width / 2)))"
            
            self.lookAtPositionYLabel.text = "\(Int(round(smoothEyeLookAtPositionY + self.phoneScreenPointSize.height / 2)))"
            
            // Calculate distance of the eyes to the camera
            let distanceL = self.eyeLNode.worldPosition - SCNVector3Zero
            let distanceR = self.eyeRNode.worldPosition - SCNVector3Zero
            
            // Average distance from two eyes
            let distance = (distanceL.length() + distanceR.length()) / 2
            
            // Update distance label value
            self.distanceLabel.text = "\(Int(round(distance * 100))) cm"
            
        }
        
    }
}
