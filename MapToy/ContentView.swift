//
//  ContentView.swift
//  MapToy
//
//  Created by Nathan Reed on 10/22/22.
//

import SwiftUI
import SpriteKit

final class ContentViewModel: ObservableObject {
    
    @Published var fileName: String?
    @Published var fileURL: URL? {
        didSet {
            fileName = fileURL?.lastPathComponent
            guard let fileURL = fileURL else { return }
            Task {
                let parser = MVTCommandParser()
                DispatchQueue.main.async {
                    self.layers = parser.load(path: fileURL.path)
                }
            }
        }
    }
    @Published var layers: [MVTLayer]?
}

struct ContentView: View {
    
    @StateObject var viewModel = ContentViewModel()
    
    var body: some View {
        VStack {
            HStack {
                Text(viewModel.fileName ?? "No file selected")
                Button("Choose File") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK {
                        self.viewModel.fileURL = panel.url
                    }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
