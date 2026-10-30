import Foundation
import RealityKit
import RKUtilities

/// Fades an entity in or out.
///
/// On systems that provide `OpacityComponent`, a recursive fade drives that component.
/// Every other case animates material blending. That includes older systems
/// (for example iOS 17) and fades started with `recursive: false`, because
/// `OpacityComponent` always affects descendants.
///
/// visionOS has no material fallback: `CustomMaterial` is unavailable there, and `OpacityComponent` has existed since visionOS 1.0.
///
/// Must be set on an entity that has at least one `ModelComponent` in its hierarchy.
public struct FadeComponent: Component {
    private static var isRegistered = false

    fileprivate var completedDuration: TimeInterval = 0

    /// When false, only this entity's materials change. `OpacityComponent` cannot express that, so those fades use material blending.
    /// Internal so the material and opacity-component files can read the fade they are applying.
    var isRecursive: Bool

    /// Set for the life of the fade so a running fade does not switch backends.
    fileprivate var usesOpacityComponent: Bool

    /// Internal so whichever backend finishes the fade can call it.
    var completion: (() -> Void)?

    public private(set) var fadeType: FadeType

    public private(set) var fadeDuration: TimeInterval = 5

    /// If fading out, initialOpacity must be greater than targetOpacity.
    /// If fading in, initialOpacity must be less than targetOpacity.
    var didCheckDirection = false

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
        self.usesOpacityComponent = Self.canUseOpacityComponent(isRecursive: isRecursive)
        self.completion = completion
        register()
    }

    /// Creates a fade that runs until the entity reaches the default target for `fadeType`.
    ///
    /// Where `OpacityComponent` is available this fade includes descendants, matching visionOS.
    /// On older systems it fades only the entity's own materials, matching the previous iOS initializer.
    public init(fadeType: FadeType,
                duration: TimeInterval = 5)
    {
        self.fadeType = fadeType
        self.fadeDuration = duration
        self.targetOpacity = fadeType == .fadeIn ? 1.0 : 0.0

        let canUseOpacityComponent = Self.canUseOpacityComponent(isRecursive: true)
        self.isRecursive = canUseOpacityComponent
        self.usesOpacityComponent = canUseOpacityComponent
        register()
    }

    private func register() {
        if Self.isRegistered == false {
            Self.isRegistered = true
            FadeSystem.registerSystem()
            FadeComponent.registerComponent()
        }
    }

    /// `OpacityComponent` fades the whole subtree. Non-recursive fades stay on the material path.
    /// visionOS always returns true because that platform cannot edit `CustomMaterial` blending.
    private static func canUseOpacityComponent(isRecursive: Bool) -> Bool {
        #if os(visionOS)
        return true
        #else
        guard isRecursive else { return false }
        if #available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 26.0, *) {
            return true
        }
        return false
        #endif
    }
}

public class FadeSystem: System {
    public required init(scene _: RealityKit.Scene) {}

    private static let fadeQuery = EntityQuery(where: .has(FadeComponent.self))

    public func update(context: SceneUpdateContext) {
        let deltaTime = context.deltaTime

        context.scene.performQuery(Self.fadeQuery).forEach { entity in
            guard var fadeComp = entity.components[FadeComponent.self] else { return }

            fadeComp.completedDuration += deltaTime

            #if os(visionOS)
            applyOpacityComponentFrame(entity: entity, fadeComp: &fadeComp)
            #else
            if #available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 26.0, *),
               fadeComp.usesOpacityComponent {
                applyOpacityComponentFrame(entity: entity, fadeComp: &fadeComp)
            } else {
                applyMaterialFrame(entity: entity, fadeComp: &fadeComp)
            }
            #endif
        }
    }

    // MARK: - Shared fade math

    enum InitialOpacityCapture {
        /// Initial opacity was stored this frame. Skip applying so the fade does not blink.
        case deferFrame
        /// Direction was invalid. The fade component has already been removed.
        case aborted
    }

    /// Returns nil when the direction was already validated on an earlier frame.
    func captureInitialOpacityIfNeeded(fadeComp: inout FadeComponent,
                                       entity: Entity,
                                       currentOpacity: Float) -> InitialOpacityCapture? {
        guard fadeComp.didCheckDirection == false else { return nil }

        if fadeComp.initialOpacity == nil {
            switch fadeComp.fadeType {
            case .fadeIn:
                fadeComp.initialOpacity = currentOpacity == 1 ? 0 : currentOpacity
            case .fadeOut:
                fadeComp.initialOpacity = currentOpacity == 0 ? 1 : currentOpacity
            }
        }

        fadeComp.didCheckDirection = true

        guard let initialOpacity = fadeComp.initialOpacity else {
            assertionFailure("fadeComp.initialOpacity should be set before validating fade direction")
            return nil
        }

        let directionIsValid: Bool
        switch fadeComp.fadeType {
        case .fadeIn:
            directionIsValid = initialOpacity < fadeComp.targetOpacity
        case .fadeOut:
            directionIsValid = initialOpacity > fadeComp.targetOpacity
        }

        guard directionIsValid else {
            print("For fade out, initial opacity must be greater than target opacity")
            print("For fade in, initial opacity must be less than target opacity")
            entity.components.remove(FadeComponent.self)
            fadeComp.completion?()
            return .aborted
        }

        return .deferFrame
    }

    func interpolatedOpacity(fadeComp: FadeComponent) -> (newOpacity: Float, didFinish: Bool) {
        let percentCompleted = Float(fadeComp.completedDuration / fadeComp.fadeDuration).clamped(0, 1)

        if fadeComp.fadeType == .fadeIn && percentCompleted < 1 {
            let initialOpacity = fadeComp.initialOpacity ?? 0
            let interpolatedChange = (fadeComp.targetOpacity - initialOpacity) * percentCompleted
            return (initialOpacity + interpolatedChange, false)
        }

        if fadeComp.fadeType == .fadeOut && percentCompleted < 1 {
            let initialOpacity = fadeComp.initialOpacity ?? 1
            let interpolatedChange = (initialOpacity - fadeComp.targetOpacity) * percentCompleted
            return (initialOpacity - interpolatedChange, false)
        }

        return (fadeComp.targetOpacity, true)
    }
}

public extension Entity {
    /// Fades the entity in over a specified duration.
    /// - Parameters:
    ///   - duration: How long it takes for the entity to fade in, in seconds.
    ///   - initialOpacity: Opacity to start from. When nil, the current opacity is used.
    ///   - targetOpacity: Opacity to end on. Defaults to fully opaque.
    ///   - recursive: When true, descendants fade as well. Systems with `OpacityComponent` use it for this case. Pass false to fade only this entity's materials. visionOS ignores this and always uses `OpacityComponent`.
    ///   - completion: Called when the fade has finished.
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
    ///   - duration: How long it takes for the entity to fade out, in seconds.
    ///   - initialOpacity: Opacity to start from. When nil, the current opacity is used.
    ///   - targetOpacity: Opacity to end on. Defaults to fully transparent.
    ///   - recursive: When true, descendants fade as well. Systems with `OpacityComponent` use it for this case. Pass false to fade only this entity's materials. visionOS ignores this and always uses `OpacityComponent`.
    ///   - completion: Called when the fade has finished.
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
                      completion: (() -> Void)?) {
        guard findEntity(where: { $0.components.has(ModelComponent.self) }) != nil else { return }

        // OpacityComponent multiplies through descendants, so those fades replace any descendant fade.
        // visionOS always uses that component.
        #if os(visionOS)
        let clearsDescendantFades = true
        #else
        let clearsDescendantFades = recursive
        #endif
        if clearsDescendantFades {
            visit(using: {
                $0.components.remove(FadeComponent.self)
            })
        }

        // Completion is called once, from the entity that owns this component.
        components.set(FadeComponent(fadeType: fadeType,
                                     duration: duration,
                                     initialOpacity: initialOpacity,
                                     targetOpacity: targetOpacity,
                                     isRecursive: recursive,
                                     completion: completion))
    }
}
