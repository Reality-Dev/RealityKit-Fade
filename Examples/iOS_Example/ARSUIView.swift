import ARKit
import RealityKit
import RKAssetLoading
import RKFade

class ARSUIView: ARView {
    
    private var fadedOut = false
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        // Does Not work with Simple Materials.
//        let box = ModelEntity.makeBox()
//        addEntityToScene(box)
//        box.fadeIn()
    
        runNewConfig()

        // These particular modeles help with testing to make sure that models with multiple materials and textures work,
        // as well as recursive fading applied to descendants.
        RKAssetLoader.loadModelEntitiesAsync(entityNames: "rocket", "cupcake") { [weak self] loadedEntities in

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
                      fadeDuration: TimeInterval = 1)
    {
        Timer.scheduledTimer(withTimeInterval: fadeDuration + 0.1, repeats: true) { [weak self] _ in
            let fadedOut = self?.fadedOut ?? true
            
            if fadedOut {
                entity.fadeIn(duration: fadeDuration) { [weak self] in
                    print("Finished fade in")
                    self?.fadedOut = false
                }
            } else {
                entity.fadeOut(duration: fadeDuration) { [weak self] in
                    print("Finished fade out")
                    self?.fadedOut = true
                }
            }
        }
    }
    
    func runNewConfig() {
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