//
//  MBTilesView.swift
//  MapToy
//
//  Created by Nathan Reed on 10/23/22.
//

import SwiftUI
import SpriteKit

final class MBTilesViewModel: ObservableObject {
    
    struct TilePath: Hashable {
        let x: Int
        let y: Int
        let z: Int
    }
    
    @Published var fileName: String?
    @Published var fileURL: URL? {
        didSet {
            fileName = fileURL?.lastPathComponent
        }
    }
    @Published var layers: [TilePath: [MVTLayer]]?
    
    @Published var sqSize: Int?
    @Published var tlTilePath: TilePath?
    
    func loadTiles(paths: [TilePath]) {
        layers = nil
        Task {
            guard let path = fileURL?.path else {
                return
            }
            let loader = MBTilesLoader(mbTilesPath: path)
            
            var loadedTileData = [TilePath: Data]()
            
            for tilePath in paths {
                if let data = loader.loadTile(x: tilePath.x, y: tilePath.y, z: tilePath.z) {
                    loadedTileData[tilePath] = data
                }
            }
            
            let parser = MVTParser()
            
            let parsedTileData = loadedTileData.compactMap { (path, data) in
                if let parsed = parser.load(from: data) {
                    return (path, parsed)
                } else {
                    return nil
                }
            }
            
            DispatchQueue.main.async {
                self.layers = Dictionary(uniqueKeysWithValues: parsedTileData)
            }
        }
    }
}

struct MBTilesView: View {
    
    @StateObject var viewModel = MBTilesViewModel()
    
    @State var xString: String = ""
    @State var yString: String = ""
    @State var zString: String = ""
    
    @State var mapSquareSize: String = "1"
    
    private var tilePaths = [MBTilesViewModel.TilePath]()
    
    var body: some View {
        VStack {
            FileChooserView(fileName: $viewModel.fileName, fileURL: $viewModel.fileURL)
            VStack {
                HStack {
                    Text("Top left tile of ")
                    TextField("", text: $mapSquareSize)
                        .frame(maxWidth: 20)
                    Text("x \(mapSquareSize) ")
                    Text("map: ")
                    Spacer()
                }
                HStack {
                    TextField("Tile Z", text: $zString)
                    TextField("Tile X", text: $xString)
                    TextField("Tile Y", text: $yString)
                    Button("Go") {
                        let x = Int(xString)
                        let y = Int(yString)
                        let z = Int(zString)
                        let sqSize = Int(mapSquareSize)
                        guard let x, let y, let z, let sqSize else { return }
                        // Figure out which tiles are involved for the S x S map
                        var tilePaths = [MBTilesViewModel.TilePath]()
                        for addX in 0..<sqSize {
                            for addY in 0..<sqSize {
                                tilePaths.append(.init(x: x + addX, y: y + addY, z: z))
                            }
                        }
                        self.viewModel.sqSize = sqSize
                        self.viewModel.tlTilePath = MBTilesViewModel.TilePath(x: x, y: y, z: z)
                        self.viewModel.loadTiles(paths: tilePaths)
                    }
                }
            }
            .padding()
            if let layers = viewModel.layers {
                MultiMBTilesView(viewModel: viewModel)
            } else {
                Text("No layers to display")
            }
        }
        
    }
}

struct MultiMBTilesView: View {
    
    @ObservedObject var viewModel: MBTilesViewModel
    
    var body: some View {
        if let layers = viewModel.layers {
            GeometryReader { geo in
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(tilesArr, id: \.self) { tileRow in
                        GridRow {
                            ForEach(tileRow, id: \.self) { tileLayers in
                                if let tileLayers {
                                    SpriteView(scene: MapScene(size: CGSize(width: round(geo.size.width / Double(viewModel.sqSize!)), height: round(geo.size.height / Double(viewModel.sqSize!))), layers: tileLayers))
                                } else {
                                    Color.black
                                }
                            }
                            .frame(width: round(geo.size.width / Double(viewModel.sqSize!)), height: round(geo.size.height / Double(viewModel.sqSize!)))
                        }
                    }
                }
            }
            .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }
    
    var tilesArr: [[[MVTLayer]?]] {
        get {
            let layers = viewModel.layers!
            let sqSize = viewModel.sqSize!
            let tlTilePath = viewModel.tlTilePath!
            
            var returnRows = [[[MVTLayer]?]]()
            
            for row_idx in 0..<sqSize {
                var row = [[MVTLayer]?]()
                for col_idx in 0..<sqSize {
                    // can be nil
                    let parsedTileData = layers[MBTilesViewModel.TilePath(x: tlTilePath.x + col_idx, y: tlTilePath.y + row_idx, z: tlTilePath.z)]
                    row.append(parsedTileData)
                }
                returnRows.append(row)
            }
            
            return returnRows
        }
    }
}

struct MBTilesView_Previews: PreviewProvider {
    static var previews: some View {
        MBTilesView()
    }
}
