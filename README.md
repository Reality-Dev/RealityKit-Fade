# RKFade

This package enables easy, convenient fading in and fading out in RealityKit.

Fading uses RealityKit's [`OpacityComponent`](https://developer.apple.com/documentation/realitykit/opacitycomponent) where that component is available:

- iOS 18.0 or later
- iPadOS 18.0 or later
- Mac Catalyst 18.0 or later
- macOS 15.0 or later
- tvOS 26.0 or later
- visionOS 1.0 or later

`OpacityComponent` fades the entity and its descendants, and it leaves the materials themselves unchanged. The material and texture issues below do not apply to those fades.

On earlier systems, such as iOS 17 and macOS 14, fading updates the `blending` property of each material instead.

`fadeIn` and `fadeOut` take a `recursive` parameter that defaults to `true`. Pass `false` to fade only the entity you call the method on. `OpacityComponent` always includes descendants, so `recursive: false` updates material blending instead. visionOS has no material-blending fallback (`CustomMaterial` is unavailable), so every fade on visionOS uses `OpacityComponent`.

On the material blending path, SimpleMaterial will not work - Materials must be PhysicallyBased, Custom, or Unlit.
You can use this to see what kinds of materials your entity uses:
``` swift
            myEntity.modifyMaterials({
                print($0)
                return $0
            })
```

## Requirements

- iOS 15.0 or later, macOS 12.0 or later, Mac Catalyst 15.0 or later, tvOS 26.0 or later, or visionOS 1.0 or later
- Swift 5.9


## Installation

### Swift Package Manager

Add the URL of this repository to your Xcode 15 or later project under:
    File > Add Packages
    `https://github.com/Reality-Dev/RealityKit-Fade`

## Usage

- Add `import RKFade` to the top of your swift file to start.
- Create an entity with a model. PhysicallyBasedMaterial and UnlitMaterial work on every supported system. CustomMaterial works everywhere except visionOS.
    - Materials on entities loaded from usdz files are PhysicallyBasedMaterials.
    - Where `OpacityComponent` is available, other visual components such as SimpleMaterial fade as well.
- Call `.fadeIn()` or `.fadeOut()` on the entity, optionally passing in a fade duration.

## Important

These notes apply when a fade updates material blending. That is the path used on systems without `OpacityComponent`, and when `recursive` is `false` on platforms that can edit materials. visionOS always uses `OpacityComponent`.

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
