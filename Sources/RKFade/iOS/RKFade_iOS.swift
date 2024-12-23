
import Foundation
import RealityKit
import RKUtilities

#if !os(visionOS)
/// MUST be set on an Entity with at least one PhysicallyBasedMaterial, UnlitMaterial or CustomMaterial.
public struct FadeComponent: Component {
    fileprivate static var isRegistered = false

    fileprivate var completedDuration: TimeInterval = 0

    fileprivate var isRecursive: Bool

    fileprivate var completion: (() -> Void)?

    public private(set) var fadeType: FadeType

    public private(set) var fadeDuration: TimeInterval = 5
    
    ///If fading out, initialOpacity must be greater than targetOpacity.
    ///If fading in, initialOpacity must be less than targetOpacity.
    fileprivate var didCheckDirection = false
    
    fileprivate var initialOpacity: Float?
    
    fileprivate var targetOpacity: Float

    public enum FadeType {
        case fadeIn, fadeOut
    }

    fileprivate init(fadeType: FadeType,
                     duration: TimeInterval = 5,
                     initialOpacity: Float?,
                     targetOpacity: Float?,
                     isRecursive: Bool,
                     completion: (() -> Void)?)
    {
        self.fadeType = fadeType

        self.fadeDuration = duration
        
        self.initialOpacity = initialOpacity
        
        self.targetOpacity = targetOpacity ?? (fadeType == .fadeIn ? 1.0 : 0.0)

        self.isRecursive = isRecursive

        self.completion = completion

        self.register()
    }
    
    private func register(){
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

        self.fadeDuration = duration
        
        self.targetOpacity = fadeType == .fadeIn ? 1.0 : 0.0

        self.isRecursive = false

        self.register()
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

            if fadeComp.didCheckDirection == false {
                
                //Gather textures BEFORE the first material typecast, to make sure the textures do not disappear.
                if fadeComp.isRecursive {
                    entity.visit {
                        if $0.components.has(TexturesComponent.self) == false {
                            $0.gatherTextures()
                        }
                    }
                } else {
                    if entity.components.has(TexturesComponent.self) == false {
                        entity.gatherTextures()
                    }
                }
                
                if let modelEnt = entity.findFirstHasModelComponent(),
                   let modelComp = modelEnt.modelComponent,
                   let firstMat = modelComp.materials.first(where: {$0 is HasBlending}) as? HasBlending,
                   setInitialOpacity(mat: firstMat, fadeComp: &fadeComp, fadeEnt: entity){
                    //Must call `setInitialOpacity` before `updateOpacity` in order to avoid a blink.
                    entity.components.set(fadeComp)
                    return
                }
            }
            
            let updates = updateOpacity(entity: entity, fadeComp: fadeComp)
            let didFinishFade = updates.didFinish
            let newOpacity = updates.newOpacity
            
            if fadeComp.isRecursive {
                entity.visit {
                    updateOpacity(on: $0, newOpacity: newOpacity)
                    $0.applyTextures()
                }
            } else {
                updateOpacity(on: entity, newOpacity: newOpacity)
                entity.applyTextures()
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
    
    private func updateOpacity(on entity: Entity,
                               newOpacity: Float) {
        guard var model = entity.modelComponent else {return}
            
            var materials = model.materials
            
            for (index, material) in materials.enumerated() {
                if var hasBlending = material as? HasBlending {
                    
                    hasBlending.opacityScale = newOpacity
                    
                    materials[index] = hasBlending

                }  else if var simpleMat = material as? SimpleMaterial {
                    updateSimpleMaterial(&simpleMat,
                                               newOpacity: newOpacity)
                    materials[index] = simpleMat
                }
            }
        
        model.materials = materials
        entity.modelComponent = model
    }

    private func setInitialOpacity(mat: HasBlending,
                                   fadeComp: inout FadeComponent,
                                   fadeEnt: Entity) -> Bool {
        guard fadeComp.didCheckDirection == false else { return false }

        if fadeComp.initialOpacity == nil {
            //If the initialOpacity was not set manually by the user, read what the current opacity scale is of the material.
            switch fadeComp.fadeType {
            case .fadeIn:
                // Start the fade in from something less than 1.
                fadeComp.initialOpacity = mat.opacityScale == 1 ? 0 : mat.opacityScale
            case .fadeOut:
                // Start the fade out from something greater than 0.
                fadeComp.initialOpacity = mat.opacityScale == 0 ? 1 : mat.opacityScale
            }
        }
        
        return checkDirection(mat: mat, fadeComp: &fadeComp, fadeEnt: fadeEnt)
    }

    
    private func checkDirection(mat: HasBlending,
                                fadeComp: inout FadeComponent,
                                fadeEnt: Entity) -> Bool {
        func removeFade(fadeComp: FadeComponent,
                        fadeEnt: Entity){
           print("For fade out, initial opacity must be greater than target opacity")
           print("For fade in, initial opacity must be less than target opacity")
           fadeEnt.components.remove(FadeComponent.self)
           fadeComp.completion?()
        }
        fadeComp.didCheckDirection = true
        
        guard let initialOpacity = fadeComp.initialOpacity else {
            assertionFailure("fadeComp.initialOpacity should be set before calling checkDirection")
            return false
        }
        
        switch fadeComp.fadeType {
        case .fadeIn:

            guard initialOpacity < fadeComp.targetOpacity else {
                removeFade(fadeComp: fadeComp, fadeEnt: fadeEnt)
                return false }
        case .fadeOut:

            guard initialOpacity > fadeComp.targetOpacity else {
                removeFade(fadeComp: fadeComp, fadeEnt: fadeEnt)
                return false }
        }
        
        return true
    }

    private func updateOpacity(entity: Entity,
                               fadeComp: FadeComponent) -> (newOpacity: Float, didFinish: Bool)
    {
        var opacity: Float
        var didFinishFade = false

        let percentCompleted = Float(fadeComp.completedDuration / fadeComp.fadeDuration).clamped(0, 1)

        if fadeComp.fadeType == .fadeIn && percentCompleted < 1 {
            let initialOpacity: Float = fadeComp.initialOpacity ?? 0

            let interpolatedChange = (fadeComp.targetOpacity - initialOpacity) * percentCompleted
            opacity = initialOpacity + interpolatedChange

        } else if fadeComp.fadeType == .fadeOut && percentCompleted < 1 {
            let initialOpacity: Float = fadeComp.initialOpacity ?? 1

            let interpolatedChange = (initialOpacity - fadeComp.targetOpacity) * percentCompleted
            opacity = initialOpacity - interpolatedChange

        } else {
            // The fade has completed
            opacity = fadeComp.targetOpacity

            didFinishFade = true
        }
        return (opacity, didFinishFade)
    }


    private func updateSimpleMaterial(_ simpleMat: inout SimpleMaterial,
                                      newOpacity: Float)
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
        simpleMat.tintColor = Material.Color.white.withAlphaComponent(CGFloat(newOpacity))
    }
}

public extension Entity {
    fileprivate func modifyMaterialsNonRecursive(_ closure: (RealityKit.Material) throws -> RealityKit.Material) rethrows {
        guard
            let hasModel = findEntity(where: {$0.components.has(ModelComponent.self)}),
            var comp = hasModel.modelComponent
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
                initialOpacity: Float? = nil,
                targetOpacity: Float? = nil,
                recursive: Bool = true,
                completion: (() -> Void)? = nil)
    {
        fade(fadeType: .fadeIn,
             duration: duration,
             initialOpacity: initialOpacity,
             targetOpacity: targetOpacity,
             recursive: recursive,
             completion: completion)
    }

    /// Fades the entity out over a specified duration.
    /// - Parameters:
    ///   - fadeDuration: How long it takes for the entity to fade out, in seconds.
    ///   - recursive: If recursive the fade applies to all descendant entities as well. If not recursive it applies to only this entity and no descendants.
    ///   - opacityTexture: An optional CustomMaterial texture. On iOS 16 textures get lost when updating materials so passing it here makes sure it gets retained.
    ///   - completion: A closure that gets called when the fade has finished.
    func fadeOut(duration: TimeInterval = 5,
                 initialOpacity: Float? = nil,
                 targetOpacity: Float? = nil,
                 recursive: Bool = true,
                 completion: (() -> Void)? = nil)
    {
        fade(fadeType: .fadeOut,
             duration: duration,
             initialOpacity: initialOpacity,
             targetOpacity: targetOpacity,
             recursive: recursive,
             completion: completion)
    }
    
    private func fade(fadeType: FadeComponent.FadeType,
                      duration: TimeInterval,
                      initialOpacity: Float?,
                      targetOpacity: Float?,
                      recursive: Bool,
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
                                     initialOpacity: initialOpacity,
                                     targetOpacity: targetOpacity,
                                     isRecursive: recursive,
                                     completion: completion))
    }
}
#endif
