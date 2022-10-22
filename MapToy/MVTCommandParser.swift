//
//  MVTCommandParser.swift
//  MapToy
//
//  Created by Nathan Reed on 10/22/22.
//

import Foundation

/// `MVTCommandParser` implements the Mapbox Vector Tiles specification v2.1
/// It parses Protobuf-format tile data into a format that can be read by other parts of the application.
final class MVTCommandParser {
    
    enum DrawingCommand {
        case moveTo(dX: Int, dY: Int)
        case lineTo(dX: Int, dY: Int)
        case closePath
    }
    
    struct MVTFeature {
        
        enum FeatureType {
            case point
            case lineString
            case polygon
            case unknown
        }
        
        private let featureInfo: VectorTile_Tile.Feature
        
        init(featureInfo: VectorTile_Tile.Feature) {
            self.featureInfo = featureInfo
        }
        
        var drawingCommands: [DrawingCommand] {
            return parseDrawingCommands()
        }
        
        var featureType: FeatureType {
            switch featureInfo.type {
            case .linestring:
                return .lineString
            case .point:
                return .point
            case .polygon:
                return .polygon
            case .unknown:
                return .unknown
            }
        }
        
        private func parseDrawingCommands() -> [DrawingCommand] {
            let geometry = featureInfo.geometry
            var commands = [DrawingCommand]()
            var index = 0
            while index < geometry.count {
                // Read a Command Integer from the geometry at the current index and break down into its command and count parts
                let command = geometry[index]
                let commandID = command & 0x7
                let commandCount = command >> 3
                if commandID == 1 {
                    // MoveTo
                    for num in 0..<Int(commandCount) {
                        let dxIndex = index + 1 + (2*num)
                        let dyIndex = index + 2 + (2*num)
                        commands.append(.moveTo(dX: readParameterInt(raw: geometry[dxIndex]),
                                                dY: readParameterInt(raw: geometry[dyIndex])))
                    }
                    index += 1 + (2 * Int(commandCount)) // 1 for the command itself plus 2 params for each instance
                } else if commandID == 2 {
                    // LineTo
                    for num in 0..<Int(commandCount) {
                        let dxIndex = index + 1 + (2*num)
                        let dyIndex = index + 2 + (2*num)
                        commands.append(.lineTo(dX: readParameterInt(raw: geometry[dxIndex]),
                                                dY: readParameterInt(raw: geometry[dyIndex])))
                    }
                    index += 1 + (2 * Int(commandCount)) // 1 for the command itself plus 2 params for each instance
                } else if commandID == 7 {
                    // ClosePath
                    for _ in 0..<Int(commandCount) {
                        // I don't think it would make sense to do multiple close-path commands in a row but the spec is the spec
                        commands.append(.closePath)
                    }
                    index += Int(commandCount)
                } else {
                    // Invalid command
                    print("ERROR: skipping invalid command in feature \(featureInfo.id) geometry index \(index)")
                    index += 1
                }
            }
            
            return commands
            
            func readParameterInt(raw: UInt32) -> Int {
                let firstTerm = Int(raw >> 1)
                let secondTerm = -1 * Int(raw & 1)
                return firstTerm ^ secondTerm
               
            }
        }
    }
    
    struct MVTLayer {
        let name: String
        let features: [MVTFeature]
    }
    
    /// Load a tile from protobuf-encoded data at the given path
    /// Returns an array of `MVTLayer`, each of which will contain `MVTFeature` with fully-decoded drawing instructions
    func load(path: String) -> [MVTLayer]? {
        
        guard let fileData = FileManager.default.contents(atPath: path) else {
            print("ERROR: FileManager failed to read the file")
            return nil
        }
        
        guard let decodedTile = try? VectorTile_Tile(serializedData: fileData) else {
            print("ERROR: Unable to decode Protobuf-format data")
            return nil
        }
        
        // Hardcoded filter on layers we are selecting to make it easier to deal with for now
        // Will be removed later
        let toReturn = decodedTile.layers.filter({ $0.name == "waterway"})
        
        return toReturn.map { rawLayer in
            return MVTLayer(name: rawLayer.name, features: rawLayer.features.map({ rawFeature in
                return MVTFeature(featureInfo: rawFeature)
            }))
        }
    }
}
