//
//  ViewController.swift
//  FaceTrackingTrial
//
//  Created by Yasushi Nozaki on 2020/06/05.
//  Copyright © 2020 Yasushi Nozaki. All rights reserved.
//

import UIKit
import RealityKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load the "Box" scene from the "Experience" Reality File
        let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(boxAnchor)
    }
}
