//
//  ContentView.swift
//  MapToy
//
//  Created by Nathan Reed on 10/22/22.
//

import SwiftUI

final class ContentViewModel: ObservableObject {
    
    @Published var fileName: String?
    @Published var fileURL: URL? {
        didSet {
            fileName = fileURL?.lastPathComponent
            guard let fileURL = fileURL else { return }
            Task {
                let parser = MVTCommandParser()
                parser.load(path: fileURL.path)
            }
        }
    }
}

struct ContentView: View {
    
    @StateObject var viewModel = ContentViewModel()
    
    var body: some View {
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
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
