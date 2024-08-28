#if !os(visionOS)
import RealityKit

protocol Registerable: Component {
    static var isRegistered: Bool { get set }
    
    func register()
}
extension Registerable {
    internal func register(){
        if Self.isRegistered == false {
            Self.isRegistered = true
            Self.registerComponent()
        }
    }
}

public enum MaterialTextureCache {
    case pbr(PBRMaterialTextureCache)
    case custom(CustomMaterialTextureCache)
}

public struct PBRMaterialTextureCache {
    var cache: [MaterialTexture: PhysicallyBasedMaterial.Texture]
}

public struct CustomMaterialTextureCache {
    var cache: [MaterialTexture: CustomMaterial.Texture]
}

public struct TexturesComponent: Registerable {
    internal static var isRegistered = false
    
    var materialTextures: [MaterialTextureCache]
    
    public init(materialTextures: [MaterialTextureCache]) {
        self.materialTextures = materialTextures
        register()
    }
}

public enum MaterialTexture: CaseIterable {

        case ambientOcclusion
        case anisotropyLevel
        case baseColor
        case clearcoat
        case clearcoatRoughness
        case custom
        case emissiveColor
        case metallic
        case normal
        case opacity
        case roughness
        case sheen
        case specular
}

public extension Entity {
    // Components are structs so we must make a copy to modify them.
    // In iOS 16 there is a bug where copying a CustomMaterial to a new `var` will remove the textures from the material.
    // Therefore we must keep a separate reference to the texture here.
    func gatherTextures() {
        guard components.has(ModelComponent.self) else { return }
        
        var materialTextures = [MaterialTextureCache]()
        
        for material in modelComponent!.materials {
            if let customMat = material as? CustomMaterial {
                materialTextures.append(.custom(.init(cache: customMat.getTextures())))
                
            } else if let pbrMat = material as? HasPhysicallyBasedTextures {
                materialTextures.append(.pbr(.init(cache: pbrMat.getTextures())))
            }
        }
        
        components.set(TexturesComponent(materialTextures: materialTextures))
    }
    
    func applyTextures(){
        guard var model = modelComponent else {return}
        
        guard let texturesComponent = component(forType: TexturesComponent.self) else {return}
            
            var materials = model.materials
            
            for (index, material) in materials.enumerated() {
                if let hasBlending = material as? HasBlending {
                    
                    if var pbrMat = hasBlending as? HasPhysicallyBasedTextures {
                        
                        switch texturesComponent.materialTextures[index] {
                        case let .pbr(textureCache):
                            pbrMat.applyTextures(textureCache.cache)
                            
                            materials[index] = pbrMat
                        default:
                            assertionFailure("Material type mismatch. Expected HasPhysicallyBasedTextures at index \(index)")
                            continue
                        }
                        
                    } else if var customMat = hasBlending as? CustomMaterial {
                        switch texturesComponent.materialTextures[index] {
                        case let .custom(textureCache):
                            customMat.applyTextures(textureCache.cache)
                            
                            materials[index] = customMat
                        default:
                            assertionFailure("Material type mismatch. Expected CustomMaterial at index \(index)")
                            continue
                        }
                    }
                }
            }
        
        model.materials = materials
        
        modelComponent = model
    }
}

// PhysicallyBasedMaterial and UnlitMaterial use the same underlying type for their textures, so we can combine them into one protocol.
// However, CustomMaterial uses a different type for its textures, so we must handle this case separately.

extension CustomMaterial {
    private var blendingTexture: CustomMaterial.Texture? {
        get {
            switch blending {
            case .opaque:
                return nil
            case .transparent(opacity: let opacity):
                return opacity.texture
            @unknown default:
                return nil
            }
        }
        set {
            switch blending {
            case .opaque:
                blending = .transparent(opacity: .init(scale: 1.0, texture: newValue))
            case .transparent(opacity: let opacity):
                blending = .transparent(opacity: .init(scale: opacity.scale, texture: newValue))
            @unknown default:
                return
            }
        }
    }

    func getTextures() -> [MaterialTexture: CustomMaterial.Texture] {
        //No sheen or anisotropyLevel on CustomMaterial.
        let textures: [MaterialTexture: CustomMaterial.Texture] = [
            .ambientOcclusion: ambientOcclusion.texture,
            .baseColor: baseColor.texture,
            .clearcoat: clearcoat.texture,
            .clearcoatRoughness: clearcoatRoughness.texture,
            .custom: custom.texture,
            .emissiveColor: emissiveColor.texture,
            .metallic: metallic.texture,
            .normal: normal.texture,
            .opacity: blendingTexture,
            .roughness: roughness.texture,
            .specular: specular.texture
        ].compactMapValues({$0})
        
        return textures
    }
    mutating func applyTextures(_ textures: [MaterialTexture: CustomMaterial.Texture]) {
        //No sheen or anisotropyLevel on CustomMaterial.
        for texture in textures {
            switch texture.key {
            case .ambientOcclusion:
                ambientOcclusion.texture = texture.value
            case .baseColor:
                baseColor.texture = texture.value
            case .clearcoat:
                clearcoat.texture = texture.value
            case .clearcoatRoughness:
                clearcoatRoughness.texture = texture.value
            case .custom:
                custom.texture = texture.value
            case .emissiveColor:
                emissiveColor.texture = texture.value
            case .metallic:
                metallic.texture = texture.value
            case .normal:
                normal.texture = texture.value
            case .opacity:
                blendingTexture = texture.value
            case .roughness:
                roughness.texture = texture.value
            case .specular:
                specular.texture = texture.value
            case .anisotropyLevel, .sheen:
                break
            }
        }
    }
}

public protocol HasPhysicallyBasedTextures: Material {
    var blending: PhysicallyBasedMaterial.Blending { get set }
    
    func getTextures() -> [MaterialTexture: PhysicallyBasedMaterial.Texture]
    
    mutating func applyTextures(_ textures: [MaterialTexture: PhysicallyBasedMaterial.Texture])
}

extension HasPhysicallyBasedTextures {
    fileprivate var blendingTexture: PhysicallyBasedMaterial.Texture? {
        get {
            switch blending {
            case .opaque:
                return nil
            case .transparent(opacity: let opacity):
                return opacity.texture
            @unknown default:
                return nil
            }
        }
        set {
            switch blending {
            case .opaque:
                blending = .transparent(opacity: .init(scale: 1.0, texture: newValue))
            case .transparent(opacity: let opacity):
                blending = .transparent(opacity: .init(scale: opacity.scale, texture: newValue))
            @unknown default:
                return
            }
        }
    }
}

extension PhysicallyBasedMaterial: HasPhysicallyBasedTextures {
    public func getTextures() -> [MaterialTexture: PhysicallyBasedMaterial.Texture] {

        //No custom on PhysicallyBasedMaterial.
        let textures: [MaterialTexture: PhysicallyBasedMaterial.Texture] = [
            .ambientOcclusion: ambientOcclusion.texture,
            .anisotropyLevel: anisotropyLevel.texture,
            .baseColor: baseColor.texture,
            .clearcoat: clearcoat.texture,
            .clearcoatRoughness: clearcoatRoughness.texture,
            .emissiveColor: emissiveColor.texture,
            .metallic: metallic.texture,
            .normal: normal.texture,
            .opacity: blendingTexture,
            .roughness: roughness.texture,
            .sheen: sheen?.texture,
            .specular: specular.texture
        ].compactMapValues({$0})
        
        return textures
    }
    public mutating func applyTextures(_ textures: [MaterialTexture: PhysicallyBasedMaterial.Texture]) {
        //No custom on PhysicallyBasedMaterial.
        for texture in textures {
            switch texture.key {
            case .ambientOcclusion:
                ambientOcclusion.texture = texture.value
            case .anisotropyLevel:
                anisotropyLevel.texture = texture.value
            case .baseColor:
                baseColor.texture = texture.value
            case .clearcoat:
                clearcoat.texture = texture.value
            case .clearcoatRoughness:
                clearcoatRoughness.texture = texture.value
            case .emissiveColor:
                emissiveColor.texture = texture.value
            case .metallic:
                metallic.texture = texture.value
            case .normal:
                normal.texture = texture.value
            case .opacity:
                blendingTexture = texture.value
            case .roughness:
                roughness.texture = texture.value
            case .sheen:
                if var sheen {
                    sheen.texture = texture.value
                    self.sheen = sheen
                }
            case .specular:
                specular.texture = texture.value
            case .custom:
                break
            }
        }
    }
}
extension UnlitMaterial: HasPhysicallyBasedTextures {
    public func getTextures() -> [MaterialTexture: PhysicallyBasedMaterial.Texture] {
        let textures: [MaterialTexture: PhysicallyBasedMaterial.Texture] = [
            .baseColor: color.texture,
            .opacity: blendingTexture,
        ].compactMapValues({$0})
        
        return textures
    }
    public mutating func applyTextures(_ textures: [MaterialTexture: PhysicallyBasedMaterial.Texture]) {
        for texture in textures {
            switch texture.key {
            case .baseColor:
                color.texture = texture.value
            case .opacity:
                blendingTexture = texture.value
            default:
                break
            }
        }
    }
}
#endif
