/*
Copyright © 2021 Apple Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import RealityKit

public extension Entity {
    func visit(using block: (Entity) -> Void) {
        block(self)
        for child in children {
            child.visit(using: block)
        }
    }

    func modifyMaterials(_ closure: (RealityKit.Material) throws -> RealityKit.Material) rethrows {

        guard var comp = components[ModelComponent.self] as? ModelComponent else { return }
        comp.materials = try comp.materials.map { try closure($0) }
        components[ModelComponent.self] = comp
    }
    
    ///Recursively searches through self and all descendants (depth first) for an Entity that satisfies the given predicate, Not just through the direct children.
    func findEntity(where predicate: (Entity) -> Bool) -> Entity? {
        if predicate(self) {return self}
        for child in self.children {
            if let satisfier = child.findEntity(where: predicate) {return satisfier}
        }
        return nil
    }
}