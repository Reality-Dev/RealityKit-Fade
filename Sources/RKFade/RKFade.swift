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
    
    fileprivate var isRecursive: Bool
    
    fileprivate var completion: (() -> ())?
    
    var fadeType: FadeType
    var fadeDuration: TimeInterval = 5
    
    //Components are structs so we must make a copy to modify them.
    //In iOS 16 there is a bug where copying a CustomMaterial to a new `var` will remove the textures from the material.
    //Therefore we must keep a separate reference to the texture here.
    fileprivate var blendingTexture: CustomMaterial.Texture?
    
    public enum FadeType {
        case fadeIn, fadeOut
    }
    
    fileprivate init(fadeType: FadeType,
                fadeDuration: TimeInterval = 5,
                isRecursive: Bool,
                completion: (() -> ())?){
        
        self.fadeType = fadeType
        self.fadeDuration = fadeDuration
        
        self.isRecursive = isRecursive
        
        self.completion = completion
        
        if Self.isRegistered == false {
            Self.isRegistered = true
            FadeSystem.registerSystem()
            FadeComponent.registerComponent()
        }
    }
    
    public init(fadeType: FadeType,
                fadeDuration: TimeInterval = 5){
        
        self.fadeType = fadeType
        self.fadeDuration = fadeDuration
        
        self.isRecursive = false
        
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
        
            entity.modifyMaterials {
                if var mat = $0 as? HasBlending {
                    updateMaterial(material: &mat,
                                   entity: entity,
                                   fadeComp: &fadeComp)
                                   return mat
                    
                } else if let simpleMat = $0 as? SimpleMaterial {
                    return updateSimpleMaterial(simpleMat,
                                                entity: entity,
                                                fadeComp: fadeComp)
                } else {
                    return $0
                }
            }
            entity.components[FadeComponent.self] = fadeComp
        }
    }
    
    private func updateOpacity(entity: Entity,
                               fadeComp: FadeComponent) -> Float {
        var opacity: Float

        let percentCompleted = Float(fadeComp.completedDuration  / fadeComp.fadeDuration)
        
        
        if (fadeComp.fadeType == .fadeIn && percentCompleted < 1)
        {
            opacity =  min(1, percentCompleted)
            
        } else if (fadeComp.fadeType == .fadeOut && percentCompleted < 1) {
            
            opacity = max(0, 1 - percentCompleted)
            
        } else {
            //The fade has completed
            opacity = fadeComp.fadeType == .fadeIn ? 1.0 : 0.0
            
            //Stop fading.
            if fadeComp.isRecursive {
                entity.visit(using: {$0.components.remove(FadeComponent.self)})
            } else {
                entity.components.remove(FadeComponent.self)
            }
            fadeComp.completion?()
        }
        return opacity
    }
    
    private func updateMaterial(material: inout HasBlending,
                                entity: Entity,
                                fadeComp: inout FadeComponent){
        let newOpacity = self.updateOpacity(entity: entity,
                                            fadeComp: fadeComp)
        switch material.opacityBlending {
            
        case .opaque:
            material.opacityBlending = .transparent(opacity: CustomMaterial.Opacity(floatLiteral: newOpacity))
        case .transparent(opacity: let opacity):
            //Preserve any opacity textures.
            if let blendingTexture = fadeComp.blendingTexture {
                material.opacityBlending = .transparent(opacity: .init(scale: newOpacity, texture: blendingTexture))
            } else if let blendingTexture = opacity.texture {
                fadeComp.blendingTexture = blendingTexture
                material.opacityBlending = .transparent(opacity: .init(scale: newOpacity, texture: opacity.texture))
            } else {
                material.opacityBlending = .transparent(opacity: CustomMaterial.Opacity(floatLiteral: newOpacity))
            }
        @unknown default:
            break
        }
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
}


public extension Entity {
    
    
    /// Fades the entity in over a specified duration.
    /// - Parameters:
    ///   - fadeDuration: How long it takes for the entity to fade in, in seconds.
    ///   - recursive: If recursive the fade applies to all descendant entities as well. If not recursive it applies to only this entity and no descendants.
    func fadeIn(fadeDuration: TimeInterval = 5,
                recursive: Bool = true,
                completion: (() -> ())? = nil){
        
        guard let modelEnt = self.findEntity(where: {$0.components.has(ModelComponent.self)})
        else {return} //No entities with model components were found, so none can be faded.
        
        if recursive {
            self.visit(using: {
                $0.components.remove(FadeComponent.self)
            })
        }

        //Completion should only be called once, when the top-most ancestor that has a model component finishes fading.
            modelEnt.components.set(FadeComponent(fadeType: .fadeIn,
                                              fadeDuration: fadeDuration,
                                              isRecursive: recursive,
                                              completion: completion))

        if recursive {
            self.visit(using: {
                //Only entities with model components can fade.
                if $0.components.has(ModelComponent.self) &&
                    $0.components.has(FadeComponent.self) == false {
                    $0.components.set(FadeComponent(fadeType: .fadeIn,
                                                    fadeDuration: fadeDuration,
                                                    isRecursive: recursive,
                                                    completion: nil))
                }
            })
        }
    }
    
    /// Fades the entity out over a specified duration.
    /// - Parameters:
    ///   - fadeDuration: How long it takes for the entity to fade out, in seconds.
    ///   - recursive: If recursive the fade applies to all descendant entities as well. If not recursive it applies to only this entity and no descendants.
    func fadeOut(fadeDuration: TimeInterval = 5,
                 recursive: Bool = true,
                 completion: (() -> ())? = nil){
        
        guard let modelEnt = self.findEntity(where: {$0.components.has(ModelComponent.self)})
        else {return} //No entities with model components were found, so none can be faded.
        
        if recursive {
            self.visit(using: {
                $0.components.remove(FadeComponent.self)
            })
        }

        //Completion should only be called once, when the top-most ancestor that has a model component finishes fading.
            modelEnt.components.set(FadeComponent(fadeType: .fadeOut,
                                              fadeDuration: fadeDuration,
                                              isRecursive: recursive,
                                              completion: completion))

        if recursive {
            self.visit(using: {
                //Only entities with model components can fade.
                if $0.components.has(ModelComponent.self) &&
                    $0.components.has(FadeComponent.self) == false {
                    $0.components.set(FadeComponent(fadeType: .fadeOut,
                                                    fadeDuration: fadeDuration,
                                                    isRecursive: recursive,
                                                    completion: nil))
                }
            })
        }
    }
}
