import Foundation
import srt
import DiffMatchPatch

func generateSRT(jsonInputFile: String) -> [srt.Subtitle] {
    guard let jsonData = FileManager.default.contents(atPath: jsonInputFile),
          let ocrDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
          var sortedKeys = ocrDict.keys.map({ Int($0) }).sorted() else {
        fatalError("Failed to read or parse the JSON input file.")
    }
    
    if sortedKeys.isEmpty {
        fatalError("The OCR dictionary is empty.")
    }
    
    var subtitles: [srt.Subtitle] = []
    var startDate = DateComponents()
    let dmp = DiffMatchPatch()
    let similarityThreshold = 0.8
    
        for frameNumber in sortedKeys {
        guard let body = ocrDict[String(frameNumber)]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            continue
        }
        
        if !body.isEmpty {
            let startDate = DateComponents(second: frameNumber).date!
            let endDate = Calendar.current.date(byAdding: .millisecond, value: 1000, to: startDate)!
            
            let subtitle = Subtitle(nil, startDate, endDate, body)
            
            if subtitles.isEmpty {
                subtitles.append(subtitle)
            } else {
                let similarityRatio = dmp.diff_ratio(between: subtitle.content, and: subtitles.last!.content)
                
                if similarityRatio >= similarityThreshold {
                    subtitles[subtitles.count - 1].end = endDate
                } else {
                    subtitles.append(subtitle)
                }
            }
        }
    }
    
    return subtitles
}

func main() {
    guard CommandLine.arguments.count == 3 else {
        print("Usage: gen-srt <json_input> <srt_output>")
        exit(1)
    }
    
    let jsonInput = CommandLine.arguments[1]
    let srtOutput = CommandLine.arguments[2]
    
    let subtitles = generateSRT(jsonInputFile: jsonInput)
    let srtContent = srt.compose(subtitles).joined(separator: "\n")
    
    try! srtContent.write(toFile: srtOutput, atomically: true, encoding: .utf8)
}

main()