import SwiftUI
import UIKit

/// カメラ撮影。SwiftUI に標準のカメラUIがないため UIImagePickerController を包む。
/// 撮った写真はライブラリには保存せず、そのままアプリ内の記録に使う。
struct CameraPicker: UIViewControllerRepresentable {

    /// 撮影された画像。キャンセル時は呼ばれない。
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    /// 実機以外ではカメラが無い。呼び出し側でボタンの出し分けに使う。
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onFinish: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        private let onCapture: (Data) -> Void
        private let onFinish: () -> Void

        init(onCapture: @escaping (Data) -> Void, onFinish: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { onFinish() }

            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 1)
            else { return }

            // ライブラリから選んだ写真と同じ条件に揃えてから渡す。
            onCapture(ImageSupport.normalized(data) ?? data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish()
        }
    }
}
