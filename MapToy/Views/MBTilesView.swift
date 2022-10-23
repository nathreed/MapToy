//
//  MBTilesView.swift
//  MapToy
//
//  Created by Nathan Reed on 10/23/22.
//

import SwiftUI
import SpriteKit

final class MBTilesViewModel: ObservableObject {
    
    @Published var fileName: String?
    @Published var fileURL: URL? {
        didSet {
            fileName = fileURL?.lastPathComponent
        }
    }
    @Published var layers: [MVTLayer]?
    
    func loadTile(x: Int, y: Int, z: Int) {
        layers = nil
        Task {
            guard let path = fileURL?.path else {
                return
            }
            let loader = MBTilesLoader(mbTilesPath: path)
            guard let data = loader.loadTile(x: x, y: y, z: z) else {
                return
            }
            // Do the parsing on the background thread but assign on the main thread
            let parser = MVTParser()
            let parsed = parser.load(from: data)
            DispatchQueue.main.async {
                self.layers = parsed
            }
        }
    }
    
    
}

struct MBTilesView: View {
    
    @StateObject var viewModel = MBTilesViewModel()
    
    @State var xString: String = ""
    @State var yString: String = ""
    @State var zString: String = ""
    
    var body: some View {
        VStack {
            FileChooserView(fileName: $viewModel.fileName, fileURL: $viewModel.fileURL)
            HStack {
                TextField("Tile Z", text: $zString)
                TextField("Tile X", text: $xString)
                TextField("Tile Y", text: $yString)
                Button("Go") {
                    let x = Int(xString)
                    let y = Int(yString)
                    let z = Int(zString)
                    guard let x = x, let y = y, let z = z else { return }
                    self.viewModel.loadTile(x: x, y: y, z: z)
                }
            }
            .padding()
            if let layers = viewModel.layers {
                SpriteView(scene: MapScene(size: CGSize(width: 200, height: 200), layers: layers))
            } else {
                Text("No layers to display")
            }
        }
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }
}

struct MBTilesView_Previews: PreviewProvider {
    static var previews: some View {
        MBTilesView()
    }
}
