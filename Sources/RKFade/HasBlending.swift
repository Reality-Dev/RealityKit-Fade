//
//  HasBlending.swift
//  RKFade
//
//  Created by Grant Jarvis on 9/22/22.
//
import RealityKit

public protocol HasBlending: RealityKit.Material {
    var opacityBlending: CustomMaterial.Blending {get set}
    
    ///The amount of opacity specified as a single value. The final rendered opacity could also potentially be affected by the opacity texture, if any.
    var opacityScale: Float {get}
}

extension HasBlending {
    public var opacityScale: Float {
        switch opacityBlending {
        case .opaque:
            return 1.0
        case .transparent(opacity: let opacity):
            return opacity.scale
        @unknown default:
            return 1.0
        }
    }
}

extension CustomMaterial: HasBlending {
    public var opacityBlending: Blending {
        get {
            return blending
        }
        set {
            self.blending = newValue
        }
    }
}
extension PhysicallyBasedMaterial: HasBlending {
    public var opacityBlending: CustomMaterial.Blending {
        get {
            return .init(blending: self.blending)
        }
        set {
            self.blending = .init(blending: newValue)
        }
    }
}
extension UnlitMaterial: HasBlending {
    public var opacityBlending: CustomMaterial.Blending {
        get {
            return .init(blending: self.blending)
        }
        set {
            self.blending = .init(blending: newValue)
        }
    }
}
