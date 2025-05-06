//
//  networkComms.swift
//  weaver
//
//  Created by AnxiousRabbit on 2/8/23.
//

import Foundation

// Get the API Key from the environmnet variable
let apiKey = Variables.API_KEY

// Build out the JSON structure for any commands that are Strings or Errors
public struct jsonCommands {
    struct firstLayer: Codable {
        var action: String
        var table: String
        var item: item
    }
    struct item:Codable {
        var commandTime: timeC
        var sortTime: sortTimeC
        var command: commandC
        var result: resultC?
        var filename: filenameC
        var content: contentC
    }
    struct timeC: Codable {
        var N: String
    }
    struct sortTimeC: Codable {
        var N: String
    }
    struct commandC: Codable {
        var S: String
    }
    struct resultC: Codable {
        var S: String
    }
    struct filenameC: Codable {
        var S: String
    }
    struct contentC: Codable {
        var S: String
    }
}

public struct initCommands {
    struct apiRequest: Codable {
        var hostname: String
    }
}

public struct bodyResponse {
    struct bodyData: Codable {
        var body: String
        var randImage: String
        var fileType: String
    }
}

public class networkComms {
    // Set the variables for the network communications
    let url:URL
    let json:Data
    var returnData: Data!
    
    init(url: URL, json: Data) {
        self.url = url
        self.json = json
    }
    
    public func urlSend() async -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = json
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (data, _) = try! await URLSession.shared.data(for: request)
        return data
    }
}
