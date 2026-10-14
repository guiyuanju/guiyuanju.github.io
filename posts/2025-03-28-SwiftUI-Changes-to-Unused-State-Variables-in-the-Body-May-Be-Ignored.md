(:title "SwiftUI Ignores Unused State Variables"
 :date "2025-03-28")

This issue arose from a project I was working on for the “100 Days of SwiftUI” challenge. The application allows users to select a photo from their library and assign a name to it. While it's a simple app, it presented a puzzling challenge.

Below is the initial version of the code I attempted. It failed at an unexpected point—can you identify the issue?

```swift
import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var namedPhotos: [NamedPhoto] = []
    @State private var pickerItem: PhotosPickerItem?
    @State private var currentNamedPhoto: NamedPhoto? = nil
    @State private var isAskNamePresented = false

    var body: some View {
        PhotosPicker("Select a photo", selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) {_, newItem in
                Task {
                    if let data = try await newItem?.loadTransferable(type: Data.self) {
                        currentNamedPhoto = NamedPhoto(photo: data, name: "")
                        isAskNamePresented = true
                    }
                }
            }
            .sheet(isPresented: $isAskNamePresented) {
                VStack {
                    if let currentNamedPhoto = currentNamedPhoto {
                        toImage(from: currentNamedPhoto.photo)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                        if let namedPhoto = Binding($currentNamedPhoto) {
                            TextField("Name", text: namedPhoto.name)
                        }
                        Button("Add") {
                            namedPhotos.append(currentNamedPhoto)
                            isAskNamePresented = false
                        }
                    } else {
                        Text("No photo selected")
                    }
                }
            }

        List(namedPhotos, id: \.id) { photo in
            VStack(alignment: .leading) {
                Text("hi")
                toImage(from: photo.photo)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    func toImage(from data: Data) -> Image {
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        fatalError("Couldn't convert data to UIImage")
    }
}
```

To briefly explain the code: the ⁠PhotosPicker allows users to select a photo from their library. Once the photo data is loaded, the sheet is triggered by updating the variable. This is the key functionality.

However, the first time I selected a photo, the sheet was presented, but its content displayed “No photo selected.” This was unexpected!

The ⁠isAskNamePresented variable is set after we assign the photo data to ⁠currentNamedPhoto, so the sheet should recognize that ⁠currentNamedPhoto is no longer nil.

Initially, I suspected that the code inside the ⁠Task was not executed sequentially, but I quickly dismissed this idea. Swift does not behave like Haskell in this regard.

Next, I considered whether the closure might be related to the issue, as the variable captured within the closure has value semantics. This means the value does not change, but I soon realized this assumption was incorrect.

After conducting some research, I found an explanation on StackOverflow: [link](https://stackoverflow.com/questions/66262213/swiftui-sheet-unexpectedly-found-nil-while-unwrapping-an-optional-value/66267507#66267507). It states that changes are ignored because the variable is not directly used within the ⁠body property, leading SwiftUI to optimize it out.

To resolve this, I updated the code by adding one line:

```swift
var body: some View {
        if let currentNamedPhoto = currentNamedPhoto {}

        PhotosPicker("Select a photo", selection: $pickerItem, matching: .images)
// ...
```

Now, everything works as intended!

Alternatively, we can use another initializer for the sheet: [link](<https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:)>)

```swift
struct ContentView: View {
    @State private var namedPhotos: [NamedPhoto] = []
    @State private var pickerItem: PhotosPickerItem?
    @State private var currentNamedPhoto: NamedPhoto? = nil

    var body: some View {
        PhotosPicker("Select a photo", selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) {_, newItem in
                Task {
                    if let data = try await newItem?.loadTransferable(type: Data.self) {
                        currentNamedPhoto = NamedPhoto(photo: data, name: "")
                    }
                }
            }
            .sheet(item: $currentNamedPhoto, onDismiss: { }) { item in
                var newItem = NamedPhoto(photo: item.photo, name: "")
                toImage(from: newItem.photo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                TextField("Name", text: Binding(get: { newItem.name }, set: { newItem.name = $0 }))
                Button("Add") {
                    namedPhotos.append(newItem)
                    currentNamedPhoto = nil
                }
            }
// ...
```

This approach also works effectively.
