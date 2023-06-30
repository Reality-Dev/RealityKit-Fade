//
//  ARView.swift
//
//  Created by Grant Jarvis
//

import ARKit
import RealityKit
import RKAssetLoading
import RKFade

class ARSUIView: ARView {
    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        // Does Not work with Simple Materials.
//        let box = ModelEntity.makeBox()
//        addEntityToScene(box)
//        box.fadeIn()
    
        runNewConfig()

        // These particular modeles help with testing to make sure that models with multiple materials and textures work,
        // as well as recursive fading applied to descendants.
        RKAssetLoader.loadModelEntitiesAsync(entityNames: "rocket", "cupcake"){ [weak self] loadedEntities in

            let rocket = loadedEntities[0]
            let cupcake = loadedEntities[1]
            
            rocket.addChild(cupcake)
            
            self?.addEntityToScene(rocket)

            // Here is a simple way to fade in an entity:
            // rocket.fadeIn()

            // Here is a simple way to fade out an entity:
            // rocket.fadeOut()

            // Here is a way to repeatedly fade an entity in and out:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
                self?.fadeInAndOut(entity: rocket)
            }
        }
    }

    func fadeInAndOut(entity: Entity,
                      fadeDuration: TimeInterval = 1,
                      fadeIn: Bool = false)
    {
        if fadeIn {
            entity.fadeIn(duration: fadeDuration) { [weak entity, weak self] in
                guard
                    let entity = entity,
                    let self = self
                else { return }
                self.fadeInAndOut(entity: entity,
                                  fadeDuration: fadeDuration,
                                  fadeIn: false)
            }
        } else {
            entity.fadeOut(duration: fadeDuration) { [weak entity, weak self] in
                guard
                    let entity = entity,
                    let self = self
                else { return }
                self.fadeInAndOut(entity: entity,
                                  fadeDuration: fadeDuration,
                                  fadeIn: true)
            }
        }
    }
    
    func runNewConfig(){
        let worldTrackingConfig = ARWorldTrackingConfiguration()
        worldTrackingConfig.planeDetection = .horizontal
        self.session.run(worldTrackingConfig)
    }

    func addEntityToScene(_ entity: Entity) {
        let anchorEnt = AnchorEntity(.plane(.any, classification: .any, minimumBounds: .zero)) // defaults to 0,0,0 in world space.

        scene.addAnchor(anchorEnt)

        anchorEnt.addChild(entity)
        
        entity.scale = .init(repeating: 2)
    }
}
