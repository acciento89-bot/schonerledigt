import PhotosUI
import SwiftUI
import UIKit

struct EvidenceCaptureView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let routine: RoutineItem
    @State private var image: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showsCamera = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Group {
                    if let image { Image(uiImage: image).resizable().scaledToFill() }
                    else { VStack(spacing: 12) { Image(systemName: "camera.viewfinder").font(.system(size: 54, weight: .light)); Text("Optionaler Fotobeleg").font(.title3.bold()); Text("Das Foto wird nur zusammen mit dieser Bestätigung gespeichert.").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Brand.secondaryInk) }.padding(30) }
                }.frame(maxWidth: .infinity, maxHeight: 360).background(Brand.background, in: RoundedRectangle(cornerRadius: 24)).clipShape(RoundedRectangle(cornerRadius: 24))
                HStack(spacing: 12) {
                    Button { showsCamera = true } label: { Label("Kamera", systemImage: "camera.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    PhotosPicker(selection: $photoItem, matching: .images) { Label("Mediathek", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                }
                Button { store.complete(routine, evidenceImage: image); dismiss() } label: { Text(image == nil ? String(localized: "Ohne Foto bestätigen") : String(localized: "Mit Foto bestätigen")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15) }.buttonStyle(.borderedProminent)
                Spacer()
            }.padding(18).navigationTitle(routine.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
                .sheet(isPresented: $showsCamera) { CameraPicker(image: $image).ignoresSafeArea() }
                .onChange(of: photoItem) { _, item in guard let item else { return }; Task { guard let data = try? await item.loadTransferable(type: Data.self), let loaded = UIImage(data: data) else { return }; image = loaded } }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController { let controller = UIImagePickerController(); controller.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary; controller.delegate = context.coordinator; return controller }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker; init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { parent.image = info[.originalImage] as? UIImage; parent.dismiss() }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
