//
//  ml.swift
//  weaver
//
//  Created by AnxiousRabbit on 5/21/25.
//
import Vision
import AppKit
import Speech

public class imageML {
    var recognizedStrings: [String]?
    var cgImage: CGImage?
    var imagesToProc: [String]?
    var imageData: Data?
    
    init(imagesToProc: [String]? = nil) {
        self.imagesToProc = imagesToProc
    }
    
    func loadImage(path: Any, type: String){
        // Converts the image
        var nsImage: NSImage
        if type.contains("file") {
            nsImage = NSImage(byReferencingFile: path as! String)!
        }
        else {
            nsImage = NSImage(data: path as! Data)!
        }
        cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    
    func mlSetup() {
        // Check if we are processing from a file path or individual file. This may be repurposed in the future to do something different
        if imagesToProc != nil {
            for x in imagesToProc! {
                loadImage(path: x, type: "file")
            }
        }
        else {
            loadImage(path: imageData!, type: "data")
        }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage!)
        let request = VNRecognizeTextRequest(completionHandler: mlProcessing)
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        do {
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform request")
        }
        
        func mlProcessing(request: VNRequest, error: Error?) {
            guard let observations =
                    request.results as? [VNRecognizedTextObservation] else {
                return
            }
            recognizedStrings = observations.compactMap { observation in
                // Return the string of the top VNRecognizedText instance.
                return observation.topCandidates(1).first?.string
            }
        }
    }
}

public class audioML {
    var filePath: String = ""
    var processedAudio: [String] = []
    var results: String = ""
    var other: String = ""
    
//        case screenshot This would also be cool but requires rewriting the exfiltration code which has never been explored
//        case cd This could be interesting...replace every word that says slash with a slash and the user can navigate that way
    
    func normalize(_ input: String) -> String {
        // Normalizes the machine learning input and will work for single word commands
        input
            .lowercased()
            .components(separatedBy: .whitespaces)
            .joined() + ";"
    }

    func writeFile(fileData: Data) {
        let tempDir = NSTemporaryDirectory()
        let filename = UUID().uuidString + ".wav"
        filePath = (tempDir as NSString).appendingPathComponent(filename)
        do {
            try fileData.write(to: URL(fileURLWithPath: filePath))
            print("File was written successfully")
        } catch {
            self.processedAudio.append("Error writing file")
        }
    }

    func speechRecognition(completion: @escaping (String?) -> Void) {
        let speechRecognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: filePath))

        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                print("Authorization failed...")
                completion(nil)
                return
            }

            speechRecognizer?.recognitionTask(with: request, resultHandler: { (result, error) in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    completion(nil)
                }

                if let result = result, result.isFinal {
                    self.results = result.bestTranscription.formattedString
                    completion(self.results)
                }
            })
        }
    }
}
