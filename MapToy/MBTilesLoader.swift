//
//  MBTilesLoader.swift
//  MapToy
//
//  Created by Nathan Reed on 10/23/22.
//

import Foundation
import SQLite

final class MBTilesLoader {
    
    private let mbTilesPath: String
    
    init(mbTilesPath: String) {
        self.mbTilesPath = mbTilesPath
    }
    
    
    /// Load tile at the given location
    /// - Parameters:
    ///   - x: X coord of the tile
    ///   - y: Y coord of the tile, in "standard" (not flipped) Slippy map coords
    ///   - z: Zoom level of the tile
    /// - Returns: `Data` which is gzipped Mapbox Vector Tiles format data describing the requested tile
    func loadTile(x: Int, y: Int, z: Int) -> Data? {
        guard let db = try? Connection(mbTilesPath, readonly: true) else {
            print("ERROR: unable to open MBTiles database")
            return nil
        }
        
        let xCol = Expression<Int64>("tile_column")
        let yCol = Expression<Int64>("tile_row")
        let zCol = Expression<Int64>("zoom_level")
        let tileData = Expression<Data>("tile_data")
        
        let tilesTable = Table("tiles")
        
        // 2^z - 1 - y
        let mbTilesY = (1 << z) - 1 - y
        
        let tileQuery = tilesTable.select(tileData).filter(xCol == Int64(x) && yCol == Int64(mbTilesY) && zCol == Int64(z))
        
        guard let result = try? db.prepare(tileQuery) else {
            return nil
        }
        
        // Simply return the first Data we find
        for row in result {
            let data = row[tileData]
            return data
        }
        
        // If we found no data, return nil
        return nil
    }
}
