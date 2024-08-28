#if os(visionOS)
import Foundation
import RealityKit
import RKUtilities

/// MUST be set on an Entity with at least one PhysicallyBasedMaterial, UnlitMaterial or CustomMaterial.
public struct FadeComponent: Component {
    fileprivate static var isRegistered = false

    fileprivate var completedDuration: TimeInterval = 0

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
                     completion: (() -> Void)?)
    {
        self.fadeType = fadeType

        self.fadeDuration = duration
        
        self.initialOpacity = initialOpacity
        
        self.targetOpacity = targetOpacity ?? (fadeType == .fadeIn ? 1.0 : 0.0)

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
            guard var fadeComp = entity.components[FadeComponent.self] else { return }
            
            fadeComp.completedDuration += deltaTime
            
            if setInitialOpacity(fadeComp: &fadeComp, fadeEnt: entity) {
                // Must call `setInitialOpacity` before `updateOpacity` in order to avoid a blink.
                return
            }
            
            let updates = updateOpacity(entity: entity, fadeComp: fadeComp)
            
            entity.opacity = updates.newOpacity
            
            // Call completion AFTER setting the material in case the completion affects the material.
            if updates.didFinish {
                entity.components.remove(FadeComponent.self)
                
                if entity.opacity == 1.0 {
                    entity.components.remove(OpacityComponent.self)
                }
                
                fadeComp.completion?()
                
            } else {
                entity.components.set(fadeComp)
            }
        }
    }
    
    private func setInitialOpacity(fadeComp: inout FadeComponent,
                                   fadeEnt: Entity) -> Bool {
        guard fadeComp.didCheckDirection == false else { return false }
        
        if fadeComp.initialOpacity == nil {
            //If the initialOpacity was not set manually by the user, read what the current opacity scale is of the material.
            switch fadeComp.fadeType {
            case .fadeIn:
                let initialOpacity = fadeEnt.components[OpacityComponent.self]?.opacity ?? 0.0
                // Start the fade in from something less than 1.
                fadeComp.initialOpacity = initialOpacity == 1 ? 0 : initialOpacity
            case .fadeOut:
                let initialOpacity = fadeEnt.components[OpacityComponent.self]?.opacity ?? 1.0
                // Start the fade out from something greater than 0.
                fadeComp.initialOpacity = initialOpacity == 0 ? 1 : initialOpacity
            }
        }
        
        return !checkDirection(fadeComp: &fadeComp, fadeEnt: fadeEnt)
    }
    
    
    private func checkDirection(fadeComp: inout FadeComponent,
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
}

public extension Entity {
    var opacity: Float {
        get {
            return components[OpacityComponent.self]?.opacity ?? 1.0
        }
        set {
            components.set(OpacityComponent(opacity: newValue))
        }
    }
    
    /// Fades the entity in over a specified duration.
    /// - Parameters:
    ///   - fadeDuration: How long it takes for the entity to fade in, in seconds.
    ///   - opacityTexture: An optional CustomMaterial texture. On iOS 16 textures get lost when updating materials so passing it here makes sure it gets retained.
    ///   - completion: A closure that gets called when the fade has finished.
    func fadeIn(duration: TimeInterval = 5,
                initialOpacity: Float? = nil,
                targetOpacity: Float? = nil,
                completion: (() -> Void)? = nil)
    {
        fade(fadeType: .fadeIn,
             duration: duration,
             initialOpacity: initialOpacity,
             targetOpacity: targetOpacity,
             completion: completion)
    }

    /// Fades the entity out over a specified duration.
    /// - Parameters:
    ///   - fadeDuration: How long it takes for the entity to fade out, in seconds.
    ///   - opacityTexture: An optional CustomMaterial texture. On iOS 16 textures get lost when updating materials so passing it here makes sure it gets retained.
    ///   - completion: A closure that gets called when the fade has finished.
    func fadeOut(duration: TimeInterval = 5,
                 initialOpacity: Float? = nil,
                 targetOpacity: Float? = nil,
                 completion: (() -> Void)? = nil)
    {
        fade(fadeType: .fadeOut,
             duration: duration,
             initialOpacity: initialOpacity,
             targetOpacity: targetOpacity,
             completion: completion)
    }
    
    // The `OpacityComponent` is recursive by default.
    private func fade(fadeType: FadeComponent.FadeType,
                      duration: TimeInterval,
                      initialOpacity: Float?,
                      targetOpacity: Float?,
                      completion: (() -> Void)?){
        guard let _ = findEntity(where: { $0.components.has(ModelComponent.self) })
        else {
            // No entities with model components were found, so none can be faded.
            return }

        visit(using: {
            $0.components.remove(FadeComponent.self)
        })

        // Completion should only be called once, when the top-most ancestor that has a model component finishes fading.
        components.set(FadeComponent(fadeType: fadeType,
                                     duration: duration,
                                     initialOpacity: initialOpacity,
                                     targetOpacity: targetOpacity,
                                     completion: completion))
    }
}
#endif
