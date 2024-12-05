# RKFade

This package enables easy, convenient fading in and fading out in RealityKit.

> [!NOTE]
> Now with visionOS support!

SimpleMaterial will not work - Materials must be PhysicallyBased, Custom, or Unlit.
You can use this to see what kinds of materials your entity uses:
``` swift
            myEntity.modifyMaterials({
                print($0)
                return $0
            })
```

## Requirements

- iOS 15.0 or higher
- Swift 5.2
- Xcode 11


## Installation

### Swift Package Manager

Add the URL of this repository to your Xcode 11+ Project under:
    File > Add Packages
    `https://github.com/Reality-Dev/RealityKit-Fade`

## Usage

- Add `import RKFade` to the top of your swift file to start.
- Create an entity that uses PhysicallyBasedMaterial, CustomMaterial, or UnlitMaterial.
    - Materials on entities loaded from usdz files are PhysicallyBasedMaterials.
- Call `.fadeIn()` or `.fadeOut()` on the entity, optionally passing in a fade duration.

## Important

Due to a bug in RealityKit with iOS 16, all textures must be cached when animating materials, otherwise they will be lost. This package will cache all textures before performing the first fade, and store them in a `TexturesComponent` for all future fades
`CustomMaterial` uses `CustomMaterial.CustomMaterialTexture` for its textures,
and `UnlitMaterial` and `PhysicallyBasedMaterial` use `MaterialParameters.Texture` (there are type aliases as well).
I tried removing the `TexturesComponent` at the end of the fade, but then at the start of the next fade the textures were gone again.
If you wish to modify the textures between fades, try modifying the textures cached inside of the component.

UnlitMaterial:
For some reason, UnlitMaterial has to use .transparent blending BEFORE it is set on the Entity for it to work properly.

If using an opacity texture:
In some cases when loading an Entity from a USD file, even when applying an opacity texture, the `.blending` mode on the material registers as `.opaque`, so the fading system does not perserve the texture.
To solve this issue, set your material's blending mode to `.transparent` in code before attempting to fade the Entity. This will require you to load the texture from a separate file, or use a texture loaded into a different property on the material.
Example copying the metallic texture map:
``` swift
            myEntity.modifyMaterials {
                    if var pbr = $0 as? PhysicallyBasedMaterial {
                    
                        if let metallicTex = pbr.metallic.texture {
                            pbr.blending = .transparent(opacity: .init(scale: 1.0, texture: .init(metallicTex)))
                        }
                        return pbr
                    }
                    return $0
                }
```
Example loading a texture from a separate file, using [RKLoader](https://github.com/Reality-Dev/RealityKit-Asset-Loading):
``` swift
            import RKLoader
            ...
            
            guard let opacityResource = try? await RKLoader.loadTextureAsync(named: "entity_opacity")
            else {return}
            
            let opacityMap = MaterialParameterTypes.Texture(opacityResource)
            
            myEntity.modifyMaterials {
                if var pbr = $0 as? PhysicallyBasedMaterial {
                
                    pbr.blending = .transparent(opacity: .init(scale: 1.0, texture: opacityMap))
                    
                    return pbr
                }
                return $0
            }
```

## More

Pull Requests are welcome and encouraged.
