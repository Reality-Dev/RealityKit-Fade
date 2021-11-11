//
//  RKFade.swift
//
//  Created by Grant Jarvis on 11/10/21.
//

import Foundation
import RealityKit

///MUST be set on an Entity with at least one PhysicallyBasedMaterial, UnlitMaterial or CustomMaterial.
public struct FadeComponent: Component {
    var fadeType: FadeType
    var fadeDuration: Float = 5
    enum FadeType {
        case fadeIn, fadeOut
    }
}


public class FadeSystem: System {
    
    static func register(){
        FadeSystem.registerSystem()
        FadeComponent.registerComponent()
    }
    
    required public init(scene: RealityKit.Scene) {}
    
    //A query for all entities that have a FadeComponent.
    private static let fadeQuery = EntityQuery(where: .has(FadeComponent.self))
    
    public func update(context: SceneUpdateContext) {
        //Query the scene for all entities that have a FadeComponent.
        context.scene.performQuery(Self.fadeQuery).forEach { entity in
            
            guard let fadeComp = entity.components[FadeComponent.self] as? FadeComponent else {return}
        
            entity.modifyMaterials {
                if let customMat = $0 as? CustomMaterial  {
                    return updateCustomMaterial(customMat,
                                                entity: entity,
                                                fadeComp: fadeComp)
                } else if let pbrMat = $0 as? PhysicallyBasedMaterial {
                    return updatePhysicallyBasedMaterial(pbrMat,
                                                entity: entity,
                                                fadeComp: fadeComp)
                } else if let unlitMat = $0 as? UnlitMaterial {
                        
                    return updateUnlitMaterial(unlitMat,
                                        entity: entity,
                                        fadeComp: fadeComp)
                } else {
                    return $0
                }
            }
        }
    }
    
    private func updateOpacity(opacity: Float,
                               entity: Entity,
                               fadeComp: FadeComponent) -> Float {
        var opacity = opacity
        //Assuming 60 fps framerate, this is the number of frames required to complete the fade.
        let fadeFrames = 60 * fadeComp.fadeDuration
        var blendingOpacity: Float
        if (fadeComp.fadeType == .fadeIn && opacity < 1)
        {
            opacity += 1 / fadeFrames
            blendingOpacity =  min(1, opacity)
            
        } else if (fadeComp.fadeType == .fadeOut && opacity > 0) {
            
            opacity -= 1 / fadeFrames
            blendingOpacity = max(0, opacity)
            
        } else {
            //The fade has completed
            blendingOpacity = fadeComp.fadeType == .fadeIn ? 1.0 : 0.0
            entity.components[FadeComponent.self] = nil //Stop fading.
        }
        return blendingOpacity
    }
    
    
    private func updateCustomMaterial(_ customMat: CustomMaterial,
                                      entity: Entity,
                                      fadeComp: FadeComponent) -> CustomMaterial {
        
        let completion = { (customMat: CustomMaterial,
                            opacity: Float) -> RealityKit.CustomMaterial in
            var customMat = customMat
            let newOpacity = self.updateOpacity(opacity: opacity,
                                                entity: entity,
                                                fadeComp: fadeComp)
            customMat.blending = .transparent(opacity: CustomMaterial.Opacity(floatLiteral: newOpacity))
            return customMat
        }
        
        var customMat = customMat
        switch customMat.blending {
        case .opaque:
            let opacity: Float = fadeComp.fadeType == .fadeIn ? 0.0 : 1.0
            customMat.blending = .transparent(opacity: CustomMaterial.Opacity(floatLiteral: opacity))
            return completion(customMat, opacity)
        case .transparent(opacity: let opacity):
            return completion(customMat, opacity.scale)
        @unknown default:
            break
        }
        return customMat
    }
    
    private func updatePhysicallyBasedMaterial(_ pbrMat: PhysicallyBasedMaterial,
                                      entity: Entity,
                                      fadeComp: FadeComponent) -> PhysicallyBasedMaterial {
        
        let completion = { (customMat: PhysicallyBasedMaterial,
                            opacity: Float) -> RealityKit.PhysicallyBasedMaterial in
            var pbrMat = pbrMat
            let newOpacity = self.updateOpacity(opacity: opacity,
                                                entity: entity,
                                                fadeComp: fadeComp)
            pbrMat.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: newOpacity))
            return pbrMat
        }
        
        var pbrMat = pbrMat
        switch pbrMat.blending {
        case .opaque:
            let opacity: Float = fadeComp.fadeType == .fadeIn ? 0.0 : 1.0
            pbrMat.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: opacity))
            return completion(pbrMat, opacity)
        case .transparent(opacity: let opacity):
            return completion(pbrMat, opacity.scale)
        @unknown default:
            break
        }
        return pbrMat
    }
    
    
    private func updateUnlitMaterial(_ unlitMat: UnlitMaterial,
                                      entity: Entity,
                                      fadeComp: FadeComponent) -> UnlitMaterial {
        
        let completion = { (unlitMat: UnlitMaterial,
                            opacity: Float) -> RealityKit.UnlitMaterial in
            var unlitMat = unlitMat
            let newOpacity = self.updateOpacity(opacity: opacity,
                                                entity: entity,
                                                fadeComp: fadeComp)
            unlitMat.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: newOpacity))
            return unlitMat
        }
        
        var unlitMat = unlitMat
        switch unlitMat.blending {
        case .opaque:
            let opacity: Float = fadeComp.fadeType == .fadeIn ? 0.0 : 1.0
            unlitMat.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: opacity))
            return completion(unlitMat, opacity)
        case .transparent(opacity: let opacity):
            return completion(unlitMat, opacity.scale)
        @unknown default:
            break
        }
        return unlitMat
    }
}





public extension Entity {
    
    func fadeIn(fadeDuration: Float = 5){
        self.components.set(FadeComponent(fadeType: .fadeIn, fadeDuration: fadeDuration))
    }
    
    func fadeOut(fadeDuration: Float = 5){
        self.components.set(FadeComponent(fadeType: .fadeOut, fadeDuration: fadeDuration))
    }

    //From Underwater sample project
    func modifyMaterials(_ closure: (Material) throws -> Material) rethrows {
        try children.forEach { try $0.modifyMaterials(closure) }

        guard var comp = components[ModelComponent.self] as? ModelComponent else { return }
        comp.materials = try comp.materials.map { try closure($0) }
        components[ModelComponent.self] = comp
    }
}
