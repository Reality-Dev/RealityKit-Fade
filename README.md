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
