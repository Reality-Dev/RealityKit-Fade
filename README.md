# RKFade

This package enables easy, convenient fading in and fading out in RealityKit.

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

Due to a bug in RealityKit with iOS 16, all textures must be cached when animating materials, otherwise they will be lost. This package will cache all textures before performing the first fade, and store them in one or both of these two kinds of components for all future fades:
- CustomTexturesComponent
- PBRTexturesComponent
`CustomMaterial` uses `CustomMaterial.CustomMaterialTexture` for its textures,
and `UnlitMaterial` and `PhysicallyBasedMaterial` use `MaterialParameters.Texture` (there are type aliases as well). Thus we must handle them separately.
I tried removing these components at the end of the fade, but then at the start of the next fade the textures were gone again.
If you wish to modify the textures between fades, try modifying the textures cached inside of the component.

## More

Pull Requests are welcome and encouraged.
