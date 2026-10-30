import RealityKit

/// Fades driven by `OpacityComponent`.
///
/// Used for recursive fades on iOS 18+, iPadOS 18+, Mac Catalyst 18+, macOS 15+, and tvOS 26+,
/// and for every fade on visionOS.
@available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 26.0, visionOS 1.0, *)
extension FadeSystem {
    func applyOpacityComponentFrame(entity: Entity, fadeComp: inout FadeComponent) {
        let currentOpacity = opacityComponentOpacity(on: entity, fadeType: fadeComp.fadeType)
        switch captureInitialOpacityIfNeeded(fadeComp: &fadeComp, entity: entity, currentOpacity: currentOpacity) {
        case .deferFrame:
            // Store the captured opacity before applying a new value, or the first frame blinks.
            entity.components.set(fadeComp)
            return
        case .aborted:
            return
        case nil:
            break
        }

        let updates = interpolatedOpacity(fadeComp: fadeComp)
        entity.components.set(OpacityComponent(opacity: updates.newOpacity))

        if updates.didFinish {
            entity.components.remove(FadeComponent.self)

            // 1 has no visual effect. Removing it avoids multiplying later ancestor fades, and matches visionOS.
            if updates.newOpacity == 1 {
                entity.components.remove(OpacityComponent.self)
            }

            fadeComp.completion?()
        } else {
            entity.components.set(fadeComp)
        }
    }

    /// Fade-in treats a missing component as transparent. Fade-out treats it as opaque.
    /// The public `Entity.opacity` getter stays at 1 when the component is absent.
    private func opacityComponentOpacity(on entity: Entity, fadeType: FadeComponent.FadeType) -> Float {
        switch fadeType {
        case .fadeIn:
            return entity.components[OpacityComponent.self]?.opacity ?? 0
        case .fadeOut:
            return entity.components[OpacityComponent.self]?.opacity ?? 1
        }
    }
}

@available(iOS 18.0, macOS 15.0, macCatalyst 18.0, tvOS 26.0, visionOS 1.0, *)
public extension Entity {
    /// Opacity stored in `OpacityComponent`.
    ///
    /// Reading returns 1 when the entity has no opacity component.
    /// Setting installs an `OpacityComponent`, which also affects descendants.
    var opacity: Float {
        get {
            components[OpacityComponent.self]?.opacity ?? 1
        }
        set {
            components.set(OpacityComponent(opacity: newValue))
        }
    }
}
