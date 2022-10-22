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
    
    
    func load(path: String) {
        
        guard let fileData = FileManager.default.contents(atPath: path) else {
            print("ERROR: FileManager failed to read the file")
            return
        }
        
        guard let decodedTile = try? VectorTile_Tile(serializedData: fileData) else {
            print("ERROR: Unable to decode Protobuf-format data")
            return
        }
        
        print(decodedTile)
        
    }
}
