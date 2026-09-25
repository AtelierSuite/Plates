import XCTest
import CoreGraphics
import ImageIO
@testable import PlatesKitchen

final class SubjectCutoutTests: XCTestCase {
    private func image(background: CGColor, subject: CGColor, rect: CGRect) -> CGImage {
        let context = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        context.setFillColor(subject)
        context.fill(rect)
        return context.makeImage()!
    }

    func testBackgroundKeyRemovesGreenAndKeepsInteriorGreen() throws {
        let green = CGColor(srgbRed: 0, green: 0.9, blue: 0, alpha: 1)
        let context = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(green)
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        context.setFillColor(CGColor(srgbRed: 0.9, green: 0.6, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 60, y: 60, width: 80, height: 80))
        // A green garnish inside the subject is not connected to the border, so it must stay.
        context.setFillColor(green)
        context.fill(CGRect(x: 90, y: 90, width: 20, height: 20))
        let pixels = try XCTUnwrap(RGBAPixels(context.makeImage()!))
        let alpha = try XCTUnwrap(SubjectCutout.backgroundKeyMask(pixels))
        XCTAssertEqual(alpha[10 * 200 + 10], 0)
        XCTAssertEqual(alpha[100 * 200 + 100], 1)
        XCTAssertEqual(alpha[70 * 200 + 70], 1)
        let box = try XCTUnwrap(SubjectCutout.boundingBox(alpha, width: 200, height: 200))
        XCTAssertEqual(box.minX, 60)
        XCTAssertEqual(box.maxX, 139)
    }

    func testBackgroundKeyRejectsImagesWithoutPlainBackground() throws {
        let full = image(background: CGColor(gray: 1, alpha: 1), subject: CGColor(gray: 0, alpha: 1),
                         rect: CGRect(x: 0, y: 0, width: 200, height: 200))
        XCTAssertNil(SubjectCutout.backgroundKeyMask(try XCTUnwrap(RGBAPixels(full))))
    }

    func testProcessCentersOffCenterSubject() async throws {
        let offCenter = image(background: CGColor(gray: 1, alpha: 1), subject: CGColor(srgbRed: 0.8, green: 0.2, blue: 0.1, alpha: 1),
                              rect: CGRect(x: 10, y: 10, width: 60, height: 60))
        let result = try await XCTUnwrapAsync(await SubjectCutout.process(offCenter, canvas: 100))
        XCTAssertGreaterThan(result.centerOffset, 0.5)
        let centered = try XCTUnwrap(CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(result.png as CFData, nil)!, 0, nil))
        let pixels = try XCTUnwrap(RGBAPixels(centered))
        XCTAssertEqual(pixels.width, 100)
        XCTAssertGreaterThan(pixels.data[(50 * 100 + 50) * 4], 150)
    }

    private func XCTUnwrapAsync<T>(_ value: T?) async throws -> T { try XCTUnwrap(value) }
}
