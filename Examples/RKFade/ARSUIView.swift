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
        
        RKAssetLoader.loadEntityAsync(named: "gold_star"){[weak self] goldStar in

            self?.addEntityToScene(goldStar)

            //Here is a simple way to fade in an entity:
            //entity.fadeIn()
            
            //Here is a way to repeatedly fade an entity in and out:
            self?.fadeInAndOut(entity: goldStar)
        }
    }
    
    func fadeInAndOut(entity: Entity,
                      fadeDuration: TimeInterval = 4,
                      fadeIn: Bool = false){
        

            if fadeIn {
                entity.fadeIn(fadeDuration: fadeDuration)
                
            } else {
                entity.fadeOut(fadeDuration: fadeDuration)
            }
        
        Timer.scheduledTimer(withTimeInterval: fadeDuration, repeats: false){[weak self] timer in
            guard entity.isEnabled else {timer.invalidate(); return}
            
            self?.fadeInAndOut(entity: entity, fadeIn: !fadeIn)
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
