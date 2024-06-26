//
//  main.swift
//  OCR-Vision-Framework
//
//  Created by MrArthegor
//  Based on xulihang work on https://github.com/xulihang/macOCR
//

import Foundation
import Vision
import AppKit

var MODE = VNRequestTextRecognitionLevel.accurate
var USE_LANG_CORRECTION = true
let REVISION = VNRecognizeTextRequestRevision3

func main(args: [String]) -> Int {
    
    if args.count == 2 {
        if args[1] == "--langs" {
            let request = VNRecognizeTextRequest()
            request.revision = REVISION
            request.recognitionLevel = .accurate
            
            guard let langs = try? request.supportedRecognitionLanguages() else {
                print("Impossible d'obtenir la liste des languages supporté")
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
            print("Impossible de charger l'image '\(src)'")
            return 1
        }
        
        let request = VNRecognizeTextRequest { (request, error) in
            if let observations = request.results as? [VNRecognizedTextObservation] {
                var allText = ""
                
                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let string = candidate.string
                    
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
            print("Impossible d'exécuter l'OCR: \(error)")
            return 1
        }
        
        return 0
    } else {
        print("""
              Utilisation:
                language fastmode languageCorrection image_path output_path
                --langs: Liste des langues supporéetes séparées par une virgule.
                 --fast: Utiliser le mode fast (mieux pour les images avec peu de texte).
                 --accurate: Utiliser le mode accurate (mieux pour les images avec beaucoup de texte).
                 --langCorrection: Utiliser la correction automatique des langues.
              
              example:
                macOCR en false true ./image.jpg out.json
              """)
        
        return 1
    }
    return 0
}

exit(Int32(main(args: CommandLine.arguments)))
