#if os(visionOS)
import RealityKit
import RealityKitContent
import RKFade
import SwiftUI

struct ItemsView: View {
    var body: some View {
        RealityView { content in
            
            if
                let scene = await RealityKitContent.entity(named: "Scene.usda") {
                
                content.add(scene)
                
                if
                    let cupcake = scene.findEntity(named: "cupcake"),
                    let rocket = scene.findEntity(named: "rocket") {
                    
                    cupcake.fadeIn()
                    
                    rocket.fadeOut(duration: 6.0) {
                        print("Rocket fade out completed.")
                    }
                }
            }
        }
    }
}
#endif
