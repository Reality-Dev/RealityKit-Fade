//
//  RKFade.swift
//
//  Created by Grant Jarvis on 11/10/21.
//

import Foundation
import RealityKit
import UIKit

///MUST be set on an Entity with at least one PhysicallyBasedMaterial, UnlitMaterial or CustomMaterial.
public struct FadeComponent: Component {
    static var isRegistered = false
    
    fileprivate var completedDuration: TimeInterval = 0
    
    var fadeType: FadeType
    var fadeDuration: Float = 5
    public enum FadeType {
        case fadeIn, fadeOut
    }
    
    public init(fadeType: FadeType,
                fadeDuration: Float = 5){
        
        self.fadeType = fadeType
        self.fadeDuration = fadeDuration
        
        if Self.isRegistered == false {
            Self.isRegistered = true
            FadeSystem.registerSystem()
            FadeComponent.registerComponent()
        }
    }
}


public class FadeSystem: System {
    
    required public init(scene: RealityKit.Scene) {}
    
    //A query for all entities that have a FadeComponent.
    private static let fadeQuery = EntityQuery(where: .has(FadeComponent.self))
    
    public func update(context: SceneUpdateContext) {
        
        let deltaTime = context.deltaTime
        
        //Query the scene for all entities that have a FadeComponent.
        context.scene.performQuery(Self.fadeQuery).forEach { entity in
            
            guard var fadeComp = entity.components[FadeComponent.self] as? FadeComponent else {return}
            
            fadeComp.completedDuration += deltaTime
            
            entity.components[FadeComponent.self] = fadeComp
        
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
                } else if let simpleMat = $0 as? SimpleMaterial {
                    return updateSimpleMaterial(simpleMat,
                                        entity: entity,
                                        fadeComp: fadeComp)
                } else {
                    return $0
                }
            }
        }
    }
    
    private func updateOpacity(entity: Entity,
                               fadeComp: FadeComponent) -> Float {
        var opacity: Float

        let percentCompleted = (Float(fadeComp.completedDuration)  / fadeComp.fadeDuration)
        
        
        if (fadeComp.fadeType == .fadeIn && percentCompleted < 1)
        {
            opacity =  min(1, percentCompleted)
            
        } else if (fadeComp.fadeType == .fadeOut && percentCompleted < 1) {
            
            opacity = max(0, 1 - percentCompleted)
            
        } else {
            //The fade has completed
            opacity = fadeComp.fadeType == .fadeIn ? 1.0 : 0.0
            entity.components[FadeComponent.self] = nil //Stop fading.
        }
        return opacity
    }
    
    private func updateSimpleMaterial(_ simpleMat: SimpleMaterial,
                                      entity: Entity,
                                      fadeComp: FadeComponent) -> SimpleMaterial {
        
        var simpleMat = simpleMat
        var baseColor = UIColor.white
        switch simpleMat.baseColor {
        case .color(let color):
            baseColor = color
        case .texture(_):
            break
        @unknown default:
            break
        }
        let newOpacity = self.updateOpacity(entity: entity,
                                                fadeComp: fadeComp)
        simpleMat.baseColor = .color(baseColor.withAlphaComponent(CGFloat(newOpacity)))
        simpleMat.tintColor = Material.Color.white.withAlphaComponent(0.995)
        return simpleMat
    }
    
    
    private func updateCustomMaterial(_ customMat: CustomMaterial,
                                      entity: Entity,
                                      fadeComp: FadeComponent) -> CustomMaterial {
        
        let completion = { (customMat: CustomMaterial) -> RealityKit.CustomMaterial in
            var customMat = customMat
            let newOpacity = self.updateOpacity(entity: entity,
                                                fadeComp: fadeComp)
            customMat.blending = .transparent(opacity: CustomMaterial.Opacity(floatLiteral: newOpacity))
            return customMat
        }
        
        var customMat = customMat
        switch customMat.blending {
        case .opaque:
            let opacity: Float = fadeComp.fadeType == .fadeIn ? 0.0 : 1.0
            customMat.blending = .transparent(opacity: CustomMaterial.Opacity(floatLiteral: opacity))
            return completion(customMat)
        case .transparent(opacity: _):
            return completion(customMat)
        @unknown default:
            break
        }
        return customMat
    }
    
    private func updatePhysicallyBasedMaterial(_ pbrMat: PhysicallyBasedMaterial,
                                      entity: Entity,
                                      fadeComp: FadeComponent) -> PhysicallyBasedMaterial {
        
        let completion = { (customMat: PhysicallyBasedMaterial) -> RealityKit.PhysicallyBasedMaterial in
            var pbrMat = pbrMat
            let newOpacity = self.updateOpacity(entity: entity,
                                                fadeComp: fadeComp)
            pbrMat.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: newOpacity))
            return pbrMat
        }
        
        var pbrMat = pbrMat
        switch pbrMat.blending {
        case .opaque:
            let opacity: Float = fadeComp.fadeType == .fadeIn ? 0.0 : 1.0
            pbrMat.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: opacity))
            return completion(pbrMat)
        case .transparent(opacity: _):
            return completion(pbrMat)
        @unknown default:
            break
        }
        return pbrMat
    }
    
    
    private func updateUnlitMaterial(_ unlitMat: UnlitMaterial,
                                      entity: Entity,
                                      fadeComp: FadeComponent) -> UnlitMaterial {
        
        let completion = { (unlitMat: UnlitMaterial) -> RealityKit.UnlitMaterial in
            var unlitMat = unlitMat
            let newOpacity = self.updateOpacity(entity: entity,
                                                fadeComp: fadeComp)
            unlitMat.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: newOpacity))
            return unlitMat
        }
        
        var unlitMat = unlitMat
        switch unlitMat.blending {
        case .opaque:
            let opacity: Float = fadeComp.fadeType == .fadeIn ? 0.0 : 1.0
            unlitMat.blending = .transparent(opacity: PhysicallyBasedMaterial.Opacity(floatLiteral: opacity))
            return completion(unlitMat)
        case .transparent(opacity: _):
            return completion(unlitMat)
        @unknown default:
            break
        }
        return unlitMat
    }
}


public extension UIColor {
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red, green, blue, alpha)
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
