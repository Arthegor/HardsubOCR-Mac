import Foundation
import srt
import DiffMatchPatch

func generateSRT(jsonInputFile: String) -> [srt.Subtitle] {
    // Read the JSON input file and convert it to a dictionary
    guard let jsonData = FileManager.default.contents(atPath: jsonInputFile),
          let ocrDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
          var sortedKeys = ocrDict.keys.compactMap({ Int($0) }).sorted() else {
        fatalError("Failed to read or parse the JSON input file.")
    }
    
    // Check if the OCR dictionary is empty
    if sortedKeys.isEmpty {
        fatalError("The OCR dictionary is empty.")
    }
    
    var subtitles: [srt.Subtitle] = []
    let dmp = DiffMatchPatch()
    let similarityThreshold = 0.8
    
    // Iterate over the sorted keys (frame numbers) in the OCR dictionary
    for frameNumber in sortedKeys {
        guard let body = ocrDict[String(frameNumber)]?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else {
            continue
        }
        
        // Create a start date and end date based on the frame number
        let startDate = DateComponents(second: frameNumber).date!
        let endDate = Calendar.current.date(byAdding: .millisecond, value: 1000, to: startDate)!
        
        // Create a subtitle object with the start and end dates, and body content
        let subtitle = srt.Subtitle(nil, startDate, endDate, body)
        
        // If there are no subtitles yet, add this one directly
        if subtitles.isEmpty {
            subtitles.append(subtitle)
        } else {
            // Calculate the similarity ratio between the current subtitle and the last one in the list
            let similarityRatio = dmp.diff_ratio(between: subtitle.content, and: subtitles.last!.content)
            
            // If the similarity ratio is above the threshold, merge the two subtitles
            if similarityRatio >= similarityThreshold {
                subtitles[subtitles.count - 1].end = endDate
            } else {
                // Otherwise, add this subtitle to the list
                subtitles.append(subtitle)
            }
        }
    }
    
    return subtitles
}

func main() {
    // Check if the correct number of arguments is provided
    guard CommandLine.arguments.count == 3 else {
        print("Usage: gen-srt <json_input> <srt_output>")
        exit(1)
    }
    
    let jsonInput = CommandLine.arguments[1]
    let srtOutput = CommandLine.arguments[2]
    
    // Generate the SRT subtitles and write them to the output file
    let subtitles = generateSRT(jsonInputFile: jsonInput)
    let srtContent = srt.compose(subtitles).joined(separator: "\n")
    
    try! srtContent.write(toFile: srtOutput, atomically: true, encoding: .utf8)
}

main()