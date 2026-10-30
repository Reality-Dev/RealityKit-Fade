#if !os(visionOS)
import Foundation
import RealityKit
import RKUtilities

/// Fades driven by material blending.
///
/// Used on systems without `OpacityComponent` (for example iOS 17), and for `recursive: false`.
/// `OpacityComponent` always affects descendants, so a single-entity fade has to edit materials.
/// visionOS has no `CustomMaterial`, so this file is not part of that build.
extension FadeSystem {
    func applyMaterialFrame(entity: Entity, fadeComp: inout FadeComponent) {
        if fadeComp.didCheckDirection == false {
            // iOS 16 drops textures when a material value is copied. Cache them before the first cast.
            cacheTextures(on: entity, isRecursive: fadeComp.isRecursive)

            if let material = firstBlendableMaterial(on: entity) {
                switch captureInitialOpacityIfNeeded(fadeComp: &fadeComp,
                                                      entity: entity,
                                                      currentOpacity: material.opacityScale) {
                case .deferFrame:
                    entity.components.set(fadeComp)
                    return
                case .aborted:
                    return
                case nil:
                    break
                }
            }
        }

        let updates = interpolatedOpacity(fadeComp: fadeComp)

        if fadeComp.isRecursive {
            entity.visit(using: {
                applyMaterialOpacity(on: $0, newOpacity: updates.newOpacity)
                $0.applyTextures()
            })
        } else {
            applyMaterialOpacity(on: entity, newOpacity: updates.newOpacity)
            entity.applyTextures()
        }

        if updates.didFinish {
            entity.components.remove(FadeComponent.self)
            fadeComp.completion?()
        } else {
            entity.components.set(fadeComp)
        }
    }

    private func cacheTextures(on entity: Entity, isRecursive: Bool) {
        if isRecursive {
            entity.visit(using: {
                if $0.components.has(TexturesComponent.self) == false {
                    $0.gatherTextures()
                }
            })
        } else if entity.components.has(TexturesComponent.self) == false {
            entity.gatherTextures()
        }
    }

    private func firstBlendableMaterial(on entity: Entity) -> HasBlending? {
        guard let modelEntity = entity.findFirstHasModelComponent(),
              let model = modelEntity.modelComponent else { return nil }
        return model.materials.first { $0 is HasBlending } as? HasBlending
    }

    private func applyMaterialOpacity(on entity: Entity, newOpacity: Float) {
        guard var model = entity.modelComponent else { return }

        var materials = model.materials

        for (index, material) in materials.enumerated() {
            if var hasBlending = material as? HasBlending {
                hasBlending.opacityScale = newOpacity
                materials[index] = hasBlending
            } else if var simpleMat = material as? SimpleMaterial {
                updateSimpleMaterial(&simpleMat, newOpacity: newOpacity)
                materials[index] = simpleMat
            }
        }

        model.materials = materials
        entity.modelComponent = model
    }

    private func updateSimpleMaterial(_ simpleMat: inout SimpleMaterial, newOpacity: Float) {
        #if os(tvOS)
        // `baseColor` and `tintColor` are unavailable on tvOS. The tint lives on `color`.
        var color = simpleMat.color
        if let tint = color.__tint.copy(alpha: CGFloat(newOpacity)) {
            color.__tint = tint
        }
        simpleMat.color = color
        #else
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
        #endif
    }
}
#endif
