import UIKit
import Accelerate

extension UIImage {
    /// Blur, tint, and crop
    ///
    /// - Parameters:
    ///   - blurRadius: How blurry, really.
    ///   - tint: A color that will be drawn over the blur, use an alpha less than 1
    ///   - rect: If you just want a portion of the image instead of the whole thing 
    /// - Returns: A blurred, tinted and cropped copy of the image
    public func blurredImage(at blurRadius: CGFloat, tint: UIColor?, from rect: CGRect? = nil) -> UIImage? {

        if size.width < 1 || size.height < 1 {
            return nil
        }


        if blurRadius < CGFloat.ulpOfOne {
            return nil
        }
  
        let sourceImage: UIImage
        if let rectActual = rect {
            sourceImage = cropping(to: rectActual) ?? self
        }
        else {
            sourceImage = self
        }

        guard let cgImageActual = sourceImage.cgImage else {
            return nil
        }

        UIGraphicsBeginImageContextWithOptions(sourceImage.size, true, sourceImage.scale)

        guard let outputContext = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        outputContext.scaleBy(x: 1.0, y: -1.0)
        outputContext.translateBy(x: 0, y: -sourceImage.size.height)

        var format =  vImage_CGImageFormat(bitsPerComponent: 8,
                                           bitsPerPixel: 32,
                                           colorSpace: nil,
                                           bitmapInfo: [
                                            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue),
                                            .byteOrder32Little ],
                                           version: 0,
                                           decode: nil,
                                           renderingIntent: .defaultIntent)

        var effectInBuffer = vImage_Buffer()
        var scratchBuffer1 = vImage_Buffer()

        let error =
        vImageBuffer_InitWithCGImage(&effectInBuffer,
                                     &format,
                                     nil,
                                     cgImageActual,
                                     vImage_Flags(kvImagePrintDiagnosticsToConsole))
        guard error == kvImageNoError else {
            UIGraphicsEndImageContext()
            return nil
        }

        let noFlags = vImage_Flags(kvImageNoFlags)
        vImageBuffer_Init(&scratchBuffer1,
                          effectInBuffer.height,
                          effectInBuffer.width,
                          format.bitsPerPixel,
                          noFlags)

        // mental
        var outputBuffer =
            withUnsafeMutablePointer(to: &scratchBuffer1) {
                pointer -> UnsafeMutablePointer<vImage_Buffer> in
                return pointer
        }

        var inputBuffer =
            withUnsafeMutablePointer(to: &effectInBuffer) {
                pointer -> UnsafeMutablePointer<vImage_Buffer> in
            return pointer
        }

        var inputRadius = blurRadius * sourceImage.scale

        inputRadius = inputRadius - 2 < CGFloat.ulpOfOne ? 2 : inputRadius

        // Compiler can't handle it all in one line O_o
        let sq2pi = CGFloat(sqrt(2 * CGFloat.pi))
        var radius:UInt32 = UInt32(floor((inputRadius * 3 * sq2pi / 4 + 0.5) / 2))
        radius |= 1

        let tempBufferSize:Int = vImageBoxConvolve_ARGB8888(inputBuffer,
                                                            outputBuffer,
                                                            nil,
                                                            0,
                                                            0,
                                                            radius,
                                                            radius,
                                                            nil,
                                                            vImage_Flags(kvImageGetTempBufferSize | kvImageEdgeExtend))

        guard Int(tempBufferSize) > 0 else {
            UIGraphicsEndImageContext()
            return nil
        }

        let tempBuffer = malloc(tempBufferSize)
        let extendFlag = vImage_Flags(kvImageEdgeExtend)

        vImageBoxConvolve_ARGB8888(inputBuffer, outputBuffer, tempBuffer, 0, 0, radius, radius, nil, extendFlag);
        vImageBoxConvolve_ARGB8888(outputBuffer, inputBuffer, tempBuffer, 0, 0, radius, radius, nil, extendFlag);
        vImageBoxConvolve_ARGB8888(inputBuffer, outputBuffer, tempBuffer, 0, 0, radius, radius, nil, extendFlag);

        free(tempBuffer);

        let swap = inputBuffer
        inputBuffer = outputBuffer
        outputBuffer = swap

        var image = vImageCreateCGImageFromBuffer(inputBuffer,
                                                  &format,
                                                  { (_, pointer) in
                                                    free(pointer)
                                                  },
                                                  nil,
                                                  noFlags,
                                                  nil)

        if image == nil {
            image = vImageCreateCGImageFromBuffer(inputBuffer, &format, nil, nil, noFlags, nil);
            free(inputBuffer.pointee.data)
        }

        guard let imageActual = image?.takeRetainedValue() else {
            UIGraphicsEndImageContext()
            return nil
        }

        let drawRect = CGRect(origin: CGPoint.zero, size: sourceImage.size)
        outputContext.saveGState()
        outputContext.draw(imageActual, in: drawRect)
        outputContext.restoreGState()

        free(outputBuffer.pointee.data)

        if let tintActual = tint {
            outputContext.saveGState()
            outputContext.setFillColor(tintActual.cgColor)
            outputContext.fill(drawRect)
            outputContext.restoreGState()
        }

        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return result
    }
    
    func cropping(to rect: CGRect) -> UIImage? {
        if let cgCrop = cgImage?.cropping(to: rect) {
            return UIImage(cgImage: cgCrop)
        }
        else if let ciCrop = ciImage?.cropping(to:rect) {
            return UIImage(ciImage: ciCrop)
        }
        
        return nil
    }
}
