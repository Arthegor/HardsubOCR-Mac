import AVFoundation
import Foundation

// Define input and output paths
let inputURL = URL(fileReferenceLiteral: "input.mp4")
let outputFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("output_frames")

// Ensure the output folder exists
try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

// Create an asset reader to read the video file
guard let asset = AVAsset(url: inputURL) else {
    print("Failed to create asset from URL")
    exit(1)
}

let assetReader = try! AVAssetReader(asset: asset)

// Set up the output settings for the image sequences
let outputSettings: [String: Any] = [
    String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA,
    AVVideoCodecKey: AVVideoCodecType.png,
    AVVideoWidthKey: asset.preferredTransform.tx,
    AVVideoHeightKey: asset.preferredTransform.ty
]

let readerOutput = AVAssetReaderTrackOutput(track: asset.tracks[0], outputSettings: outputSettings)
readerOutput.alwaysCopiesSampleData = false
assetReader.add(readerOutput)

// Start reading the asset
assetReader.startReading()

var frameNumber = 0
let timeScale = CMTimeScale(NSEC_PER_SEC)
let timeAtZero = CMTimeMake(value: Int64(frameNumber), timescale: timeScale)

while assetReader.status == .reading {
    guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else { break }
    
    // Get the presentation timestamp of the frame
    let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    
    // Calculate the exact time for this frame (assuming a constant frame rate, adjust as needed)
    let frameTime = CMTimeMake(value: Int64(frameNumber), timescale: timeScale)
    
    // Ensure the output folder exists and create a new URL for each image file
    try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
    let outputURL = outputFolder.appendingPathComponent("\(frameNumber)_\(presentationTimeStamp.value).png")
    
    // Write the frame to a file
    if CMSampleBufferIsValid(sampleBuffer) {
        do {
            try Data(from: sampleBuffer).write(to: outputURL)
            print("Saved frame \(frameNumber) at timestamp \(presentationTimeStamp) to \(outputURL.path)")
        } catch {
            print("Failed to write frame \(frameNumber) to file: \(error)")
        }
    } else {
        print("Invalid sample buffer for frame \(frameNumber)")
    }
    
    // Increment the frame number (adjust this as needed based on your actual requirements)
    frameNumber += 1
}

if assetReader.status == .completed {
    print("Finished reading frames")
} else if assetReader.status == .failed {
    print("Failed to read frames: \(assetReader.error!)")
} else if assetReader.status == .cancelled {
    print("Reading was cancelled")
}