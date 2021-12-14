//
//  ARView.swift
//
//  Created by Grant Jarvis
//

import ARKit
import RealityKit
//import RKFade
import RKAssetLoading

class ARSUIView: ARView {

    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        let star = ModelEntity.makeBox()
        addStarToScene(star)
        star.fadeIn()
        
//        RKAssetLoader.loadEntityAsync(named: "gold_star"){ goldStar in
//
//            self.addStarToScene(goldStar)
//
//            goldStar.fadeIn()
//
//        }
    }
    
    
    func addStarToScene(_ star: Entity){
        
        let anchorEnt = AnchorEntity() //defaults to 0,0,0 in world space.
        
        self.scene.addAnchor(anchorEnt)
        
        anchorEnt.addChild(star)
        star.scale = .init(repeating: 3)
        star.position = [ 0, 0, -4]
    }
}
