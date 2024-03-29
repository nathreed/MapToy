//
//  MVTParser.swift
//  MapToy
//
//  Created by Nathan Reed on 10/22/22.
//

import Foundation
import Gzip

/// `MVTFeature` represents a feature in a layer
struct MVTFeature: Hashable {
    
    enum FeatureType: Hashable {
        case point
        case lineString
        case polygon
        case unknown
    }
    
    enum DrawingCommand: Hashable {
        case moveTo(dX: Int, dY: Int)
        case lineTo(dX: Int, dY: Int)
        case closePath
    }
    
    enum AttributeValue: Hashable {
        case string(String)
        case decimal(Double)
        case integer(Int)
        case boolean(Bool)
    }
    
    private let featureInfo: VectorTile_Tile.Feature
    let attributes: [String: AttributeValue]
    
    init(featureInfo: VectorTile_Tile.Feature, attributes: [String: AttributeValue]) {
        self.featureInfo = featureInfo
        self.attributes = attributes
    }
    
    /// Lazily-parsed array of drawing commands
    /// They are not parsed until this variable is accessed
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

/// `MVTLayer` represents a layer containing features
struct MVTLayer: Hashable, Identifiable {
    let name: String
    let features: [MVTFeature]
    
    var id: String {
        return "\(name)_\(features.count)features"
    }
}

/// `MVTParser` implements the Mapbox Vector Tiles specification v2.1
/// It parses Protobuf-format tile data into a format that can be read by other parts of the application.
final class MVTParser {
    
    /// Load a tile from protobuf-encoded data at the given path
    /// Returns an array of `MVTLayer`, each of which will contain `MVTFeature` with fully-decoded drawing instructions
    func load(path: String) -> [MVTLayer]? {
        guard let fileData = FileManager.default.contents(atPath: path) else {
            print("ERROR: FileManager failed to read the file")
            return nil
        }
        
        return load(from: fileData)
    }
    
    /// Loads a tile from the provided protobuf-encoded data, optionally gzipped
    func load(from data: Data) -> [MVTLayer]? {
        
        var dataToLoad = data
        if data.isGzipped {
            guard let unzipped = try? data.gunzipped() else {
                return nil
            }
            dataToLoad = unzipped
        }
        
        guard let decodedTile = try? VectorTile_Tile(serializedData: dataToLoad) else {
            print("ERROR: Unable to decode Protobuf-format data")
            return nil
        }
        
        // Hardcoded filter on layers we are selecting to make it easier to deal with for now
        // Will be removed later
        let allowedLayers = ["transportation", "water"]
        let toReturn = decodedTile.layers.filter({ allowedLayers.contains($0.name)})
        
        return toReturn.map { rawLayer in
            return MVTLayer(name: rawLayer.name, features: rawLayer.features.map({ rawFeature in
                return MVTFeature(featureInfo: rawFeature, attributes: parseAttributes(feature: rawFeature, layer: rawLayer))
            }))
        }
    }
    
    private func parseAttributes(feature: VectorTile_Tile.Feature, layer: VectorTile_Tile.Layer) -> [String: MVTFeature.AttributeValue] {
        var attributes = [String: MVTFeature.AttributeValue]()
        for index in stride(from: 0, to: feature.tags.count, by: 2) {
            let keyTagIndex = index
            let valueTagIndex = index+1
            
            let keyIndex = Int(feature.tags[keyTagIndex])
            let valueIndex = Int(feature.tags[valueTagIndex])
            
            let key = layer.keys[keyIndex]
            let rawValue = layer.values[valueIndex]
            
            let value: MVTFeature.AttributeValue
            if rawValue.hasIntValue {
                value = .integer(Int(rawValue.intValue))
            } else if rawValue.hasSintValue {
                value = .integer(Int(rawValue.sintValue))
            } else if rawValue.hasUintValue {
                value = .integer(Int(rawValue.uintValue))
            } else if rawValue.hasStringValue {
                value = .string(rawValue.stringValue)
            } else if rawValue.hasBoolValue {
                value = .boolean(rawValue.boolValue)
            } else if rawValue.hasFloatValue {
                value = .decimal(Double(rawValue.floatValue))
            } else if rawValue.hasDoubleValue {
                value = .decimal(rawValue.doubleValue)
            } else {
                // Should not happen
                value = .string("ERROR UNKNOWN")
            }
            
            attributes[key] = value
        }
        
        return attributes
    }
}
