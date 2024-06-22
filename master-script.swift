import Foundation

func usage() {
    print("Usage: \(CommandLine.arguments[0]) [-v <video>] [-c <crop_zone>] [-f <frames per second>] [-s <start_time>] [-e <end time>]")
    exit(1)
}

var video: String? = nil
var cropZone: String? = nil
var fps: Int? = nil
var startTime: String? = nil
var endTime: String? = nil

enum Option: String {
    case v, c, f, s, e
}

func parseArgs() -> [Option : String] {
    var optionsDict = [Option : String]()
    for arg in CommandLine.arguments[1...] {
        if let option = Option(rawValue: arg) {
            if let nextArg = CommandLine.arguments.dropFirst().first, !nextArg.hasPrefix("-") {
                optionsDict[option] = nextArg
                _ = CommandLine.arguments.popFirst() // Remove the processed argument from the array
            } else {
                usage()
            }
        }
    }
    return optionsDict
}

let options = parseArgs()
if let v = options[.v] { video = v }
if let c = options[.c] { cropZone = c }
if let f = options[.f], let fpsValue = Int(f) { fps = fpsValue }
if let s = options[.s] { startTime = s }
if let e = options[.e] { endTime = e }

guard let videoPath = video, let cropZoneStr = cropZone, let fpsValue = fps, let startTimestamp = timeToSeconds(startTime), let endTimestamp = timeToSeconds(endTime) else {
    usage()
}

func timeToSeconds(_ time: String?) -> Int? {
    guard let timeStr = time else { return nil }
    let parts = timeStr.split(separator: ":").map { Int($0)! }
    return parts[0] * 3600 + parts[1] * 60 + parts[2]
}

let timediff = endTimestamp - startTimestamp
let etimeHours = timediff / 3600
var remainingTime = timediff % 3600
let etimeMinutes = remainingTime / 60
remainingTime %= 60
let etimeSeconds = remainingTime
let etime = "\(etimeHours):\(etimeMinutes):\(etimeSeconds)"

// STEP 1: crop the video
let outputVideoPath = (videoPath as NSString).deletingPathExtension + "_video-cropped.mp4"
let commandCrop = "ffmpeg -ss \(startTimestamp) -i \(videoPath) -to \(endTimestamp) -vf \"crop=\(cropZoneStr), fps=\(fpsValue)\" -an \(outputVideoPath)"
runCommand(commandCrop)

// STEP 2: extract key frames to png images with detection threshold
let outputImagesDir = (videoPath as NSString).deletingPathExtension + "_img"
let commandExtractFrames = "ffmpeg -i \(outputVideoPath) -q:v 2 \(outputImagesDir)/snap_%04d.png"
runCommand(commandExtractFrames)

// STEP 3: run OCR on the images
let ocrOutputFile = (videoPath as NSString).deletingPathExtension + "_results.json"
let commandOCR = "python3 do-ocr.py \(outputImagesDir) \(ocrOutputFile)"
runCommand(commandOCR)

// STEP 4: generate SRT file from OCR results
let srtOutputFile = (videoPath as NSString).deletingPathExtension + ".ocr.srt"
let commandGenSRT = "python3 gen-srt.py \(ocrOutputFile) \(srtOutputFile)"
runCommand(commandGenSRT)

// STEP 5: normalize and deduplicate the SRT in-place
let srtNormalizeCommand = "srt-normalise -i \(srtOutputFile) --inplace --debug"
runCommand(srtNormalizeCommand)

let finalSrtPath = (videoPath as NSString).deletingPathExtension + ".ocr.s"