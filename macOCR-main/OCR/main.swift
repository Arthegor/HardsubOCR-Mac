//
//  main.swift
//  OCR-Vision
//
//  Created by MrArthegor
//
import Foundation
import Vision

let MODE = VNRequestTextRecognitionLevel.accurate // or .fast
var USE_LANG_CORRECTION = true
let REVISION = VNRecognizeTextRequestRevision3

func main(args: [String]) -> Int {
    
    if args.count == 2 {
        if args[1] == "--langs" {
            let request = VNRecognizeTextRequest()
            request.revision = REVISION
            request.recognitionLevel = .accurate
            
            guard let langs = try? request.supportedRecognitionLanguages() else {
                print("Failed to get supported languages")
                return 1
            }
            
            for lang in langs {
                print(lang)
            }
        
            return 0
        }
    } else if args.count > 2 {
        let (language, fastmode, languageCorrection, src) = (args[1], args[2], args[3], args[4])
        let substrings = language.split(separator: ",")
        var languages = [String]()
        
        for substring in substrings {
            languages.append(String(substring))
        }
        
        if fastmode == "true" {
            MODE = .fast
        } else {
            MODE = .accurate
        }
        
        USE_LANG_CORRECTION = languageCorrection == "true"
        
        guard let imgRef = CIImage(contentsOf: URL(fileURLWithPath: src)) else {
            print("Failed to load image '\(src)'")
            return 1
        }
        
        let request = VNRecognizeTextRequest { (request, error) in
            if let observations = request.results as? [VNRecognizedTextObservation] {
                var allText = ""
                
                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let string = candidate.string ?? ""
                    
                    allText += "\(string)\n"
                }
                
                print(allText)
            }
        }
        
        request.recognitionLevel = MODE
        request.usesLanguageCorrection = USE_LANG_CORRECTION
        request.revision = REVISION
        request.recognitionLanguages = languages
        
        do {
            try VNImageRequestHandler(ciImage: imgRef, options: [:]).perform([request])
        } catch {
            print("Failed to perform OCR: \(error)")
            return 1
        }
        
        return 0
    } else {
        print("""
              usage:
                language fastmode languageCorrection image_path output_path
                --langs: list suppported languages
              
              example:
                macOCR en false true ./image.jpg out.json
              """)
        
        return 1
    }
}

exit(main(args: CommandLine.arguments))
