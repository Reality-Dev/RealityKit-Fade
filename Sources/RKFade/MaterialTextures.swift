//
//  MaterialTextures.swift
//  
//
//  Created by Grant Jarvis on 6/30/23.
//

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

public struct CustomTexturesComponent: Registerable {
    internal static var isRegistered = false
    
    var customMaterialTextures: [[MaterialTexture: CustomMaterial.Texture]]
    
    public init(customMaterialTextures: [[MaterialTexture : CustomMaterial.Texture]]) {
        self.customMaterialTextures = customMaterialTextures
        register()
    }
}
public struct PBRTexturesComponent: Registerable {
    internal static var isRegistered = false
    
    var pbrMaterialTextures: [[MaterialTexture: PhysicallyBasedMaterial.Texture]]
    
    public init(pbrMaterialTextures: [[MaterialTexture : PhysicallyBasedMaterial.Texture]]) {
        self.pbrMaterialTextures = pbrMaterialTextures
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

//PhysicallyBasedMaterial and UnlitMaterial use the same underlying type for their textures, so we can combine them into one protocol.
//However, CustomMaterial uses a different type for its textures, so we must handle this case separately.

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
