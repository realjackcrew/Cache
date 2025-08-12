import SwiftUI

struct ContentView: View {
    @State private var note = NSAttributedString(string: "")

    private let backgroundColor = Color(red: 0.98, green: 0.97, blue: 0.96)
    private let textColor = Color(red: 0.24, green: 0.25, blue: 0.36)
    private let buttonColor = Color(red: 0.68, green: 0.68, blue: 0.72)
    private let buttonFont = Font.system(.subheadline, design: .monospaced)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    
                    Button("Copy") {
                        UIPasteboard.general.string = note.string
                    }
                    .font(buttonFont)
                    .foregroundColor(buttonColor)
                    
                    Button("Clear") {
                        note = NSAttributedString(string: "")
                    }
                    .font(buttonFont)
                    .foregroundColor(buttonColor)
                    .padding(.leading, 5)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

                ZStack {
                    RichTextEditor(text: $note)
                        .padding(.horizontal)
                        .padding(.top, 5)
                }
            }
        }
        .onAppear(perform: loadNote)
        .onDisappear(perform: saveNote)
    }
        
    private func saveNote() {
        do {
            let data = try note.data(from: .init(location: 0, length: note.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            UserDefaults.standard.set(data, forKey: "note")
        } catch {
            print("Error saving note: \(error)")
        }
    }
    
    private func loadNote() {
        guard let data = UserDefaults.standard.data(forKey: "note") else { return }
        do {
            note = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        } catch {
            print("Error loading note: \(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
