import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import Darwin

umask(0o077)
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264,
  AVVideoWidthKey: 640,
  AVVideoHeightKey: 360,
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
  assetWriterInput: input,
  sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: 640,
    kCVPixelBufferHeightKey as String: 360,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
  ]
)
writer.add(input)
guard writer.startWriting() else { fatalError("\(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)
for frame in 0..<294 {
  while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
  var pixel: CVPixelBuffer?
  guard CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel) == kCVReturnSuccess,
        let pixel else { fatalError("pixel buffer allocation failed") }
  CVPixelBufferLockBaseAddress(pixel, [])
  let context = CGContext(
    data: CVPixelBufferGetBaseAddress(pixel), width: 640, height: 360,
    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
  )!
  context.setFillColor(CGColor(gray: 0.95, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
  context.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1))
  context.fill(CGRect(x: (frame * 3) % 500, y: 140, width: 100, height: 80))
  CVPixelBufferUnlockBaseAddress(pixel, [])
  guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else {
    fatalError("\(String(describing: writer.error))")
  }
}
input.markAsFinished()
writer.finishWriting {
  if writer.status == .completed { print(destination.path); exit(0) }
  fputs("fixture encoding failed\n", stderr)
  exit(1)
}
dispatchMain()
