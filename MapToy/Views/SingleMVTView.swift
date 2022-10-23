//
//  SingleMVTView.swift
//  MapToy
//
//  Created by Nathan Reed on 10/22/22.
//

import SwiftUI
import SpriteKit

final class SingleMVTViewModel: ObservableObject {
    
    @Published var fileName: String?
    @Published var fileURL: URL? {
        didSet {
            fileName = fileURL?.lastPathComponent
            guard let fileURL = fileURL else { return }
            Task {
                let parser = MVTParser()
                DispatchQueue.main.async {
                    self.layers = parser.load(path: fileURL.path)
                }
            }
        }
    }
    @Published var layers: [MVTLayer]?
}

struct SingleMVTView: View {
    
    @StateObject var viewModel = SingleMVTViewModel()
    
    var body: some View {
        VStack {
            FileChooserView(fileName: $viewModel.fileName, fileURL: $viewModel.fileURL)
            
            if let layers = viewModel.layers {
                SpriteView(scene: MapScene(size: CGSize(width: 200, height: 200), layers: layers))
            } else {
                Text("No layers to display")
            }
            
        }
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }
}

struct SingleMVTView_Previews: PreviewProvider {
    static var previews: some View {
        SingleMVTView()
    }
}
