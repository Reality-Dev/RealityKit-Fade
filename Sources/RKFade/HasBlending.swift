//
//  HasBlending.swift
//  RKFade
//
//  Created by Grant Jarvis on 9/22/22.
//
import RealityKit

public protocol HasBlending: RealityKit.Material {
    var opacityBlending: CustomMaterial.Blending {get set}
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
