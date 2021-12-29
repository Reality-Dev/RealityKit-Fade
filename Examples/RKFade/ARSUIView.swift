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
        
        //Does Not work with Simple Materials.
//        let box = ModelEntity.makeBox()
//        addEntityToScene(box)
//        box.fadeIn()
        
        RKAssetLoader.loadEntityAsync(named: "gold_star"){ goldStar in

            self.addEntityToScene(goldStar)

            goldStar.fadeIn()
        }
    }
    
    
    func addEntityToScene(_ entity: Entity){
        
        let anchorEnt = AnchorEntity() //defaults to 0,0,0 in world space.
        
        self.scene.addAnchor(anchorEnt)
        
        anchorEnt.addChild(entity)
        entity.scale = .init(repeating: 3)
        entity.position = [ 0, 0, -4]
    }
}
