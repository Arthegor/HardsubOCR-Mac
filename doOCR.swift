import Foundation
import PathKit

// Define a dictionary to hold the OCR results
var ocrDict: [String: String] = [:]
let lock = NSLock()

// Function to perform OCR on an image file
func ocrFile(_ image: Path) {
    let bucketKey = image.stem.replacingOccurrences(of: "snap_", with: "")
    
    // Check if the file name is already in the dictionary, and skip it if so
    lock.lock()
    defer { lock.unlock() }
    if ocrDict[bucketKey] != nil { return }
    
    do {
        // Run the OCR command on the file, and capture the output from stdout
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/OCR")
        process.arguments = ["fr", "false", "true", image.absolute().string]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let errorOutput = String(process.standardError?.readDataToEndOfFile().string ?? "")
        
        if !errorOutput.isEmpty {
            print("Erreur", errorOutput)
        } else {
            lock.lock()
            defer { lock.unlock() }
            print("\(bucketKey) \(output)")
            ocrDict[bucketKey] = output
        }
    } catch {
        print("Une erreur est apparue: ", error.localizedDescription)
    }
}

// Main function to execute the script
if CommandLine.arguments.count != 3 {
    print("Usage: do-ocr.swift <folder_name> <results_file>")
    exit(1)
}

let folderName = CommandLine.arguments[1]
let resultsFile = CommandLine.arguments[2]

// Load the existing dictionary from JSON file, or create an empty one
let resFile = Path(resultsFile)
if resFile.exists {
    do {
        let data = try Data(contentsOf: resFile.url)
        ocrDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] ?? [:]
    } catch {
        print("Failed to load dictionary from file: \(error)")
    }
}

// Get the list of image files in the specified folder
let imgPaths = Path(folderName).glob("*.png").map { $0 }

// Use DispatchQueue for concurrency
DispatchQueue.concurrentPerform(iterations: imgPaths.count) { index in
    ocrFile(imgPaths[index])
}

// Write the results back into JSON file after all tasks are done
do {
    let data = try JSONSerialization.data(withJSONObject: ocrDict, options: .prettyPrinted)
    try data.write(to: resFile.url)
} catch {
    print("Failed to write dictionary to file: \(error)")
}