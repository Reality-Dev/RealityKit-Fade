//
//  RKFade.swift
//
//  Created by Grant Jarvis on 11/10/21.
//

import Foundation
import RealityKit
import RKUtilities

/// MUST be set on an Entity with at least one PhysicallyBasedMaterial, UnlitMaterial or CustomMaterial.
public struct FadeComponent: Component {
    static var isRegistered = false

    fileprivate var completedDuration: TimeInterval = 0

    fileprivate var isRecursive: Bool

    fileprivate var completion: (() -> Void)?

    public private(set) var fadeType: FadeType

    public private(set) var fadeDuration: TimeInterval = 5

    fileprivate var initialOpacity: Float?

    // Components are structs so we must make a copy to modify them.
    // In iOS 16 there is a bug where copying a CustomMaterial to a new `var` will remove the textures from the material.
    // Therefore we must keep a separate reference to the texture here.
    fileprivate var blendingTexture: CustomMaterial.Texture?

    public enum FadeType {
        case fadeIn, fadeOut
    }

    fileprivate init(fadeType: FadeType,
                     duration: TimeInterval = 5,
                     isRecursive: Bool,
                     opacityTexture: CustomMaterial.Texture?,
                     completion: (() -> Void)?)
    {
        self.fadeType = fadeType

        fadeDuration = duration

        self.isRecursive = isRecursive

        blendingTexture = opacityTexture

        self.completion = completion

        if Self.isRegistered == false {
            Self.isRegistered = true
            FadeSystem.registerSystem()
            FadeComponent.registerComponent()
        }
    }

    public init(fadeType: FadeType,
                duration: TimeInterval = 5)
    {
        self.fadeType = fadeType

        fadeDuration = duration

        isRecursive = false

        if Self.isRegistered == false {
            Self.isRegistered = true
            FadeSystem.registerSystem()
            FadeComponent.registerComponent()
        }
    }
}

public class FadeSystem: System {
    public required init(scene _: RealityKit.Scene) {}

    // A query for all entities that have a FadeComponent.
    private static let fadeQuery = EntityQuery(where: .has(FadeComponent.self))

    public func update(context: SceneUpdateContext) {
        let deltaTime = context.deltaTime

        // Query the scene for all entities that have a FadeComponent.
        context.scene.performQuery(Self.fadeQuery).forEach { entity in

            guard var fadeComp = entity.components[FadeComponent.self] as? FadeComponent else { return }

            fadeComp.completedDuration += deltaTime

            let updates = updateOpacity(entity: entity, fadeComp: fadeComp)
            let didFinishFade = updates.didFinish
            let newOpacity = updates.newOpacity
            
            let materialUpdate: (RealityKit.Material) throws -> RealityKit.Material = { [weak self] in

                    if var mat = $0 as? HasBlending {
                        self?.setInitialOpacity(mat: mat, fadeComp: &fadeComp)

                        self?.updateMaterial(material: &mat,
                                       newOpacity: newOpacity,
                                                       fadeComp: &fadeComp)

                        return mat

                    } else if var simpleMat = $0 as? SimpleMaterial {
                        self?.updateSimpleMaterial(&simpleMat,
                                             newOpacity: newOpacity,
                                             fadeComp: fadeComp)
                        return simpleMat
                    } else {
                        return $0
                    }
            }
            
            do {
                if fadeComp.isRecursive {
                    try entity.modifyMaterials(materialUpdate)
                } else {
                    try entity.modifyMaterialsNonRecursive(materialUpdate)
                }
            } catch {
                print("Error modifying opacity \(error)")
            }


            // Call completion AFTER setting the material in case the completion affects the material.
            if didFinishFade {
                entity.components.remove(FadeComponent.self)
                fadeComp.completion?()
            } else {
                entity.components.set(fadeComp)
            }
        }
    }

    private func setInitialOpacity(mat: HasBlending, fadeComp: inout FadeComponent) {
        guard fadeComp.initialOpacity == nil else { return }

        switch fadeComp.fadeType {
        case .fadeIn:
            // Start the fade in from something less than 1.
            fadeComp.initialOpacity = mat.opacityScale == 1 ? 0 : mat.opacityScale
        case .fadeOut:
            // Start the fade out from something greater than 0.
            fadeComp.initialOpacity = mat.opacityScale == 0 ? 1 : mat.opacityScale
        }
    }

    private func updateOpacity(entity: Entity,
                               fadeComp: FadeComponent) -> (newOpacity: Float, didFinish: Bool)
    {
        var opacity: Float
        var didFinishFade = false

        let percentCompleted = Float(fadeComp.completedDuration / fadeComp.fadeDuration).clamped(0, 1)

        if fadeComp.fadeType == .fadeIn && percentCompleted < 1 {
            let initialOpacity: Float = fadeComp.initialOpacity ?? 0

            let interpolatedChange = (1 - initialOpacity) * percentCompleted
            opacity = initialOpacity + interpolatedChange

        } else if fadeComp.fadeType == .fadeOut && percentCompleted < 1 {
            let initialOpacity: Float = fadeComp.initialOpacity ?? 1

            let interpolatedChange = initialOpacity * percentCompleted
            opacity = initialOpacity - interpolatedChange

        } else {
            // The fade has completed
            opacity = fadeComp.fadeType == .fadeIn ? 1.0 : 0.0

            didFinishFade = true
        }
        return (opacity, didFinishFade)
    }

    private func updateMaterial(material: inout HasBlending,
                                newOpacity: Float,
                                fadeComp: inout FadeComponent)
    {

        switch material.opacityBlending {
        case .opaque:
            material.opacityBlending = .transparent(opacity: CustomMaterial.Opacity(floatLiteral: newOpacity))
        case let .transparent(opacity: opacity):
            // Preserve any opacity textures.
            if let blendingTexture = fadeComp.blendingTexture {
                material.opacityBlending = .transparent(opacity: .init(scale: newOpacity, texture: blendingTexture))

            } else if let blendingTexture = opacity.texture {
                var fadeComp = fadeComp
                fadeComp.blendingTexture = blendingTexture

                material.opacityBlending = .transparent(opacity: .init(scale: newOpacity, texture: opacity.texture))

            } else {
                material.opacityBlending = .transparent(opacity: CustomMaterial.Opacity(floatLiteral: newOpacity))
            }
        @unknown default:
            break
        }
    }

    private func updateSimpleMaterial(_ simpleMat: inout SimpleMaterial,
                                      newOpacity: Float,
                                      fadeComp: FadeComponent)
    {
        var baseColor = SimpleMaterial.Color.white
        switch simpleMat.baseColor {
        case let .color(color):
            baseColor = color
        case .texture:
            break
        @unknown default:
            break
        }

        simpleMat.baseColor = .color(baseColor.withAlphaComponent(CGFloat(newOpacity)))
        simpleMat.tintColor = Material.Color.white.withAlphaComponent(0.995)
    }
}

public extension Entity {
    fileprivate func modifyMaterialsNonRecursive(_ closure: (RealityKit.Material) throws -> RealityKit.Material) rethrows {
        guard
            let hasModel = findEntity(where: {$0.components.has(ModelComponent.self)}),
            var comp = hasModel.components[ModelComponent.self] as? ModelComponent
        else { return }
        comp.materials = try comp.materials.map { try closure($0) }
        hasModel.components[ModelComponent.self] = comp
    }

    /// Fades the entity in over a specified duration.
    /// - Parameters:
    ///   - fadeDuration: How long it takes for the entity to fade in, in seconds.
    ///   - recursive: If recursive the fade applies to all descendant entities as well. If not recursive it applies to only this entity and no descendants.
    ///   - opacityTexture: An optional CustomMaterial texture. On iOS 16 textures get lost when updating materials so passing it here makes sure it gets retained.
    ///   - completion: A closure that gets called when the fade has finished.
    func fadeIn(duration: TimeInterval = 5,
                recursive: Bool = true,
                opacityTexture: CustomMaterial.Texture? = nil,
                completion: (() -> Void)? = nil)
    {
        fade(fadeType: .fadeIn,
             duration: duration,
             recursive: recursive,
             opacityTexture: opacityTexture,
             completion: completion)
    }

    /// Fades the entity out over a specified duration.
    /// - Parameters:
    ///   - fadeDuration: How long it takes for the entity to fade out, in seconds.
    ///   - recursive: If recursive the fade applies to all descendant entities as well. If not recursive it applies to only this entity and no descendants.
    ///   - opacityTexture: An optional CustomMaterial texture. On iOS 16 textures get lost when updating materials so passing it here makes sure it gets retained.
    ///   - completion: A closure that gets called when the fade has finished.
    func fadeOut(duration: TimeInterval = 5,
                 recursive: Bool = true,
                 opacityTexture: CustomMaterial.Texture? = nil,
                 completion: (() -> Void)? = nil)
    {
        fade(fadeType: .fadeOut,
             duration: duration,
             recursive: recursive,
             opacityTexture: opacityTexture,
             completion: completion)
    }
    
    private func fade(fadeType: FadeComponent.FadeType,
                      duration: TimeInterval,
                      recursive: Bool,
                      opacityTexture: CustomMaterial.Texture?,
                      completion: (() -> Void)?){
        guard let _ = findEntity(where: { $0.components.has(ModelComponent.self) })
        else {
            // No entities with model components were found, so none can be faded.
            return }

        if recursive {
            visit(using: {
                $0.components.remove(FadeComponent.self)
            })
        }

        // Completion should only be called once, when the top-most ancestor that has a model component finishes fading.
        components.set(FadeComponent(fadeType: fadeType,
                                              duration: duration,
                                              isRecursive: recursive,
                                              opacityTexture: opacityTexture,
                                              completion: completion))
    }
}
