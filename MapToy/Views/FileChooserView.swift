//
//  FileChooserView.swift
//  MapToy
//
//  Created by Nathan Reed on 10/23/22.
//

import Foundation
import SwiftUI

struct FileChooserView: View {
    
    @Binding var fileName: String?
    @Binding var fileURL: URL?
    
    var body: some View {
        HStack {
            Text(fileName ?? "No file selected")
            Button("Choose File") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK {
                    self.fileURL = panel.url
                }
            }
        }
        .padding()
    }
}
