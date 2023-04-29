//
//  MapScene.swift
//  MapToy
//
//  Created by Nathan Reed on 10/22/22.
//

import Foundation
import SpriteKit

final class MapScene: SKScene {
    
    init(size: CGSize, layers: [MVTLayer]) {
        super.init(size: size)
        scaleMode = .aspectFit
        // Render the features in each layer
        for layer in layers {
            for feature in layer.features {
                let commands = feature.drawingCommands
                switch feature.featureType {
                case .lineString:
                    handleLineStringFeature(commands: commands)
                case .polygon:
                    handlePolygonFeature(commands: commands)
                default:
                    print("\(feature.featureType) features are UNSUPPORTED! skipping")
                }
            }
        }
    }
    
    private func handleLineStringFeature(commands: [MVTFeature.DrawingCommand]) {
        // Cursor is in MVT coords to make the logic easy
        var cursorX = 0
        var cursorY = 0
        var currentLinePath: CGMutablePath?
        for command in commands {
            switch command {
            case .moveTo(let dX, let dY):
                if let path = currentLinePath {
                    // This moveTo command is the start of a new path, so we need to wrap the old one
                    addLine(path: path)
                    currentLinePath = CGMutablePath()
                    currentLinePath!.move(to: spriteKitCoord(mvtCoordX: cursorX + dX, mvtCoordY: cursorY + dY))
                } else {
                    currentLinePath = CGMutablePath()
                    currentLinePath!.move(to: spriteKitCoord(mvtCoordX: cursorX + dX, mvtCoordY: cursorY + dY))
                }
                cursorX += dX
                cursorY += dY
            case .lineTo(let dX, let dY):
                if currentLinePath == nil {
                    // This case is indicative of an invalid command sequence
                    // Nonetheless, start a new path so we can continue drawing something
                    // The results will be wrong (missing some lines) but at least we won't crash
                    print("ERROR: lineTo without moveTo, indicates invalid command sequence!")
                    currentLinePath = CGMutablePath()
                }
                currentLinePath!.addLine(to: spriteKitCoord(mvtCoordX: cursorX + dX, mvtCoordY: cursorY + dY))
                
                
                addLine(path: currentLinePath!)
                
                // Update cursor
                cursorX += dX
                cursorY += dY
            case .closePath:
                break
            }
        }
        if let linePath = currentLinePath {
            addLine(path: linePath)
        }
    }
    
    private func handlePolygonFeature(commands: [MVTFeature.DrawingCommand]) {
        print("drawing polygon")
        // Command sequence will be an exterior ring and 0 or more interior rings
        // For now interior rings are unsupported
        var cursorX = 0
        var cursorY = 0
        var currentPolygonPath: CGMutablePath?
        var currentPolygonMVTVertices: [(Int, Int)]?
        for command in commands {
            switch command {
            case .moveTo(let dX, let dY):
                if currentPolygonPath != nil {
                    print("ERROR/RECOVERABLE: moveTo command while a polygon ongoing. Closing polygon and assuming start of new one, this may give incorrect results!")
                    currentPolygonPath!.closeSubpath()
                    addPolygon(path: currentPolygonPath!)
                }
                
                
                currentPolygonPath = CGMutablePath()
                currentPolygonMVTVertices = [(Int, Int)]()
                currentPolygonPath!.move(to: spriteKitCoord(mvtCoordX: cursorX + dX, mvtCoordY: cursorY + dY))
                currentPolygonMVTVertices?.append((cursorX + dX, cursorY + dY))
                cursorX += dX
                cursorY += dY
                
            case .lineTo(let dX, let dY):
                if currentPolygonPath == nil {
                    // This is incorrect but we should do something anyway
                    print("ERROR/RECOVERABLE: Incorrect polygon")
                    currentPolygonPath = CGMutablePath()
                    currentPolygonPath!.move(to: spriteKitCoord(mvtCoordX: cursorX, mvtCoordY: cursorY))
                    currentPolygonMVTVertices!.append((cursorX, cursorY))
                }
                currentPolygonPath!.addLine(to: spriteKitCoord(mvtCoordX: cursorX + dX, mvtCoordY: cursorY + dY))
                currentPolygonMVTVertices!.append((cursorX + dX, cursorY + dY))
                // update cursor
                cursorX += dX
                cursorY += dY
            case .closePath:
                guard currentPolygonPath != nil else { return }
                // Make sure this is an exterior ring polygon (positive area per surveyor's formula)
                if surveyorsFormulaArea(mvtCoordVertices: currentPolygonMVTVertices!) > 0 {
                    // Positive area, exterior ring polygon
                    currentPolygonPath!.closeSubpath()
                    addPolygon(path: currentPolygonPath!)
                    currentPolygonPath = nil
                    currentPolygonMVTVertices = nil
                } else {
                    // Negative area, interior ring polygon
                    // Need to reset the polygon but don't return since we need to keep looking for more polygons in this feature
                    print("WARNING: interior ring polygon detected, ignoring!")
                    currentPolygonPath = nil
                    currentPolygonMVTVertices = nil
                }
            }
        }
    }
    
    /// Calculate the area of the polygon ring described by the vertices, which are given in MVT tile coordinate space
    /// This uses the "surveyor's formula" linked from the spec (https://en.wikipedia.org/wiki/Shoelace_formula)
    private func surveyorsFormulaArea(mvtCoordVertices: [(Int, Int)]) -> Double {
        
        // because of the way wikipedia defines the formula where vertex 0 = vertex n, we need a special subscript to make the loop code not ugly
        // also this lets us iterate from 1 to n to more closely match the "mathy" formula on wikipedia
        func xSub(_ i: Int) -> Int {
            // NOTE: not sure if this is completely accurate, I sort of hacked it until it worked
            // Might be worth re-evaluating this code against the wikipedia version
            if i == 0 || i == mvtCoordVertices.count + 1 {
                return mvtCoordVertices[mvtCoordVertices.count - 1].0
            } else {
                return mvtCoordVertices[i-1].0
            }
        }
        
        // adjusts the index to enable 1 to n iteration instead of 0 to n-1
        func ySub(_ i: Int) -> Int {
            return mvtCoordVertices[i-1].1
        }
        
        var accumulatedArea = 0
        for i in 1...mvtCoordVertices.count {
            accumulatedArea += ySub(i) * (xSub(i-1) - xSub(i+1))
        }
        
        return 0.5 * Double(accumulatedArea)
    }
    
    private func spriteKitCoord(mvtCoordX: Int, mvtCoordY: Int) -> CGPoint {
        // The MVT coord system starts at the top left with 0,0 and ends at the bottom right with 4096, 4096
        // For an MVT coord, figure out its % of 4096 and apply that to our size to start
        let xRatio = Double(mvtCoordX) / 4096.0
        let yRatio = Double(mvtCoordY) / 4096.0
        
        
        let spriteX = (xRatio) * self.size.width
        let spriteY = self.size.height - ((yRatio) * self.size.height)
        
        return CGPoint(x: spriteX, y: spriteY)
    }
    
    private func addLine(path: CGPath) {
        let shape = SKShapeNode(path: path)
        shape.strokeColor = .red
        shape.lineWidth = 0.2
        shape.lineJoin = .round
        
        addChild(shape)
    }
    
    private func addPolygon(path: CGPath) {
        let shape = SKShapeNode(path: path)
        shape.strokeColor = .blue
        shape.fillColor = .blue
        
        addChild(shape)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
