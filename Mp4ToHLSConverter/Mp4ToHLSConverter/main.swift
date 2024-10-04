import Foundation

// Define the error structure
struct RuntimeError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) {
        self.description = description
    }
}

// Function to transcode MOV files to HLS
func transcodeMOVToHLS(inFolder folderPath: String, toHLSFolder hlsFolderPath: String, segmentDuration: Int = 10) throws {
    let fileManager = FileManager.default
    let folderURL = URL(fileURLWithPath: folderPath)
    let hlsFolderURL = URL(fileURLWithPath: hlsFolderPath)
    
    // Check if the provided folders exist
    guard fileManager.fileExists(atPath: folderURL.path) else {
        throw RuntimeError("The provided folder URL does not exist.")
    }
    
    guard fileManager.fileExists(atPath: hlsFolderURL.path) else {
        throw RuntimeError("The provided HLS folder URL does not exist.")
    }
    
    // Get the list of MOV files in the folder
    let files = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
    let movFiles = files.filter { $0.pathExtension.lowercased() == "mov" }
    
    guard !movFiles.isEmpty else {
        throw RuntimeError("No MOV files found in the specified folder.")
    }
    
    for file in movFiles {
        let fileName = file.deletingPathExtension().lastPathComponent
        guard let folderNumber = fileName.split(separator: " ").first else {
            throw RuntimeError("Unable to extract folder number from file name: \(fileName)")
        }
        
        let outputFolder = hlsFolderURL.appendingPathComponent(String(folderNumber))
        try fileManager.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = [
            "-hwaccel", "videotoolbox",
            "-i", file.path,
            "-c:v", "h264_videotoolbox",
            "-b:v", "5M",
            "-start_number", "0",
            "-hls_time", "\(segmentDuration)",
            "-hls_list_size", "0",
            "-f", "hls", "\(outputFolder.path)/index.m3u8"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print(output)
        }
        
        if process.terminationStatus != 0 {
            throw RuntimeError("FFmpeg process failed for file: \(fileName)")
        }
    }
    
    print("All files have been processed successfully.")
}

// Example usage
let folderPath = "/Volumes/Samsung_T5/Exodai/Exodai Academy/Exports/Practical-Xcode/"
let hlsFolderPath = "/Volumes/Samsung_T5/Exodai/Exodai Academy/Exports/Practical-Xcode/hls/"
do {
    try transcodeMOVToHLS(inFolder: folderPath, toHLSFolder: hlsFolderPath, segmentDuration: 10)
} catch {
    print("Error: \(error)")
}
//
//
//import Foundation
//
//// Define the error structure
//struct RuntimeError: Error, CustomStringConvertible {
//    var description: String
//    init(_ description: String) {
//        self.description = description
//    }
//}
//
//// Function to transcode a single MOV file to HLS
//func transcodeMOVToHLSFile(file: URL, hlsFolderURL: URL, segmentDuration: Int) throws {
//    let fileManager = FileManager.default
//    let fileName = file.deletingPathExtension().lastPathComponent
//    guard let folderNumber = fileName.split(separator: " ").first else {
//        throw RuntimeError("Unable to extract folder number from file name: \(fileName)")
//    }
//    
//    let outputFolder = hlsFolderURL.appendingPathComponent(String(folderNumber))
//    try fileManager.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
//    
//    let process = Process()
//    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
//    process.arguments = [
//        "-hwaccel", "videotoolbox",
//        "-i", file.path,
//        "-c:v", "h264_videotoolbox",
//        "-b:v", "5M",
//        "-start_number", "0",
//        "-hls_time", "\(segmentDuration)",
//        "-hls_list_size", "0",
//        "-f", "hls", "\(outputFolder.path)/index.m3u8"
//    ]
//    
//    let pipe = Pipe()
//    process.standardOutput = pipe
//    process.standardError = pipe
//    
//    try process.run()
//    process.waitUntilExit()
//    
//    let data = pipe.fileHandleForReading.readDataToEndOfFile()
//    if let output = String(data: data, encoding: .utf8) {
//        print(output)
//    }
//    
//    if process.terminationStatus != 0 {
//        throw RuntimeError("FFmpeg process failed for file: \(fileName)")
//    }
//}
//
//// Function to transcode MOV files to HLS in parallel
//func transcodeMOVToHLS(inFolder folderPath: String, toHLSFolder hlsFolderPath: String, segmentDuration: Int = 10) throws {
//    let fileManager = FileManager.default
//    let folderURL = URL(fileURLWithPath: folderPath)
//    let hlsFolderURL = URL(fileURLWithPath: hlsFolderPath)
//    
//    // Check if the provided folders exist
//    guard fileManager.fileExists(atPath: folderURL.path) else {
//        throw RuntimeError("The provided folder URL does not exist.")
//    }
//    
//    guard fileManager.fileExists(atPath: hlsFolderURL.path) else {
//        throw RuntimeError("The provided HLS folder URL does not exist.")
//    }
//    
//    // Get the list of MOV files in the folder
//    let files = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
//    let movFiles = files.filter { $0.pathExtension.lowercased() == "mov" }
//    
//    guard !movFiles.isEmpty else {
//        throw RuntimeError("No MOV files found in the specified folder.")
//    }
//    
//    // Create a dispatch group to wait for all tasks to finish
//    let dispatchGroup = DispatchGroup()
//    let queue = DispatchQueue(label: "transcodeQueue", attributes: .concurrent)
//    
//    for file in movFiles {
//        dispatchGroup.enter()
//        queue.async {
//            do {
//                try transcodeMOVToHLSFile(file: file, hlsFolderURL: hlsFolderURL, segmentDuration: segmentDuration)
//                print("Processed file: \(file.lastPathComponent)")
//            } catch {
//                print("Error processing file \(file.lastPathComponent): \(error)")
//            }
//            dispatchGroup.leave()
//        }
//    }
//    
//    // Wait for all tasks to complete
//    dispatchGroup.wait()
//    
//    print("All files have been processed successfully.")
//}
//
//// Example usage
//let folderPath = "/Volumes/Samsung_T5/Exodai/Exodai Academy/Exports/Advanced-Swift/"
//let hlsFolderPath = "/Volumes/Samsung_T5/Exodai/Exodai Academy/Exports/Advanced-Swift/hls/"
//do {
//    try transcodeMOVToHLS(inFolder: folderPath, toHLSFolder: hlsFolderPath, segmentDuration: 10)
//} catch {
//    print("Error: \(error)")
//}



