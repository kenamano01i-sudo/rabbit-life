import Foundation
import UIKit

enum ImageSupport {

    /// 端末内保存用にリサイズ・再圧縮する。
    /// 1日1枚とはいえ長期運用でストレージが膨らむため、長辺 1600px / JPEG 0.8 に落とす。
    static func normalized(_ data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }

        let scale = min(1, maxDimension / longest)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
