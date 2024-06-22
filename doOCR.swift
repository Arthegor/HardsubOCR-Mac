import Foundation

// Define a dictionary to hold the OCR results
var ocrDict: [String: String] = [:]
let lock = NSLock()

// Function to perform OCR on an image file
func ocrFile(_ image: URL) async {
    let bucketKey = image.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "snap_", with: "")
    
    // Check if the file name is already in the dictionary, and skip it if so
    if ocrDict[bucketKey] != nil { return }
    
    do {
        // Run the OCR command on the file, and capture the output from stdout
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/OCR")
        process.arguments = ["fr", "false", "true", image.path]
        
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
if let data = try? Data(contentsOf: URL(fileURLWithPath: resultsFile)) {
    if let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
        ocrDict = jsonDict
    }
}

// Get the list of image files in the specified folder
let fileManager = FileManager.default
var imgPaths: [URL] = []
if let enumerator = fileManager.enumerator(atPath: folderName) {
    while let element = enumerator.nextObject() as? String, element.hasSuffix(".png") {
        imgPaths.append(URL(fileURLWithPath: folderName + "/" + element))
    }
}

// Use TaskGroup for concurrent execution of OCR tasks
await withTaskGroup(of: Void.self) { group in
    for image in imgPaths {
        group.addTask {
            await ocrFile(image)
        }
    }
}

// Write the results back into JSON file after all tasks are done
do {
    let data = try JSONSerialization.data(withJSONObject: ocrDict, options: .prettyPrinted)
    try data.write(to: URL(fileURLWithPath: resultsFile))
} catch {
    print("Failed to write dictionary to file: \(error)")
}