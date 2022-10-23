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
                default:
                    break
                }
            }
        }
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
    }
    
    private func addLine(path: CGPath) {
        let shape = SKShapeNode(path: path)
        shape.strokeColor = .red
        shape.lineWidth = 0.2
        
        addChild(shape)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
