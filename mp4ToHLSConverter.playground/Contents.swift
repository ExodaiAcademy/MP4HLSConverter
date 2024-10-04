import Foundation

// Define the error structure
struct RuntimeError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) {
        self.description = description
    }
}

// Function to run an asynchronous process with real-time feedback
@discardableResult
func runProcessAsync(executableURL: URL, arguments: [String]) async throws -> String {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    
    var outputData = Data()
    
    let outputHandle = outputPipe.fileHandleForReading
    let errorHandle = errorPipe.fileHandleForReading
    
    outputHandle.readabilityHandler = { pipe in
        let data = pipe.availableData
        if !data.isEmpty {
            outputData.append(data)
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
        }
    }
    
    errorHandle.readabilityHandler = { pipe in
        let data = pipe.availableData
        if !data.isEmpty {
            if let output = String(data: data, encoding: .utf8) {
                print("Error: \(output)")
            }
        }
    }
    
    return try await withCheckedThrowingContinuation { continuation in
        process.terminationHandler = { _ in
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            
            if process.terminationStatus == 0 {
                if let output = String(data: outputData, encoding: .utf8) {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: RuntimeError("Failed to decode FFmpeg output"))
                }
            } else {
                continuation.resume(throwing: RuntimeError("FFmpeg process failed with exit code \(process.terminationStatus)"))
            }
        }
        
        do {
            try process.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

// Function to transcode MP4 files to HLS concurrently with real-time feedback
func transcodeMP4ToHLS(inFolder folderPath: String, segmentDuration: Int = 10, maxConcurrentTasks: Int = 4) async throws {
    let fileManager = FileManager.default
    let folderURL = URL(fileURLWithPath: folderPath)
    
    // Check if the provided folder URL exists
    guard fileManager.fileExists(atPath: folderURL.path) else {
        throw RuntimeError("The provided folder URL does not exist.")
    }
    
    // Ensure the "hls" directory exists within the provided folder
    let hlsFolderURL = folderURL.appendingPathComponent("hls")
    if !fileManager.fileExists(atPath: hlsFolderURL.path) {
        try fileManager.createDirectory(at: hlsFolderURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    // Get the list of MP4 or MOV files in the folder
    let files = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
    let mp4Files = files.filter { $0.pathExtension.lowercased() == "mp4" || $0.pathExtension.lowercased() == "mov" }
    
    guard !mp4Files.isEmpty else {
        throw RuntimeError("No MP4 or MOV files found in the specified folder.")
    }
    
    try await withThrowingTaskGroup(of: Void.self) { taskGroup in
        var activeTasks = 0
        
        for file in mp4Files {
            if activeTasks >= maxConcurrentTasks {
                // Wait for a task to complete before starting a new one
                try await taskGroup.next()
                activeTasks -= 1
            }
            
            taskGroup.addTask {
                let fileName = file.deletingPathExtension().lastPathComponent
                guard let folderNumber = fileName.split(separator: " ").first else {
                    throw RuntimeError("Unable to extract folder number from file name: \(fileName)")
                }
                
                let outputFolder = hlsFolderURL.appendingPathComponent(String(folderNumber))
                try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
                
                let ffmpegURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
                let arguments = [
                    "-i", file.path,
                    "-c:v", "libx264",
                    "-preset", "slow",
                    "-b:v", "5M",
                    "-start_number", "0",
                    "-hls_time", "\(segmentDuration)",
                    "-hls_list_size", "0",
                    "-f", "hls", "\(outputFolder.path)/index.m3u8"
                ]
                
                let output = try await runProcessAsync(executableURL: ffmpegURL, arguments: arguments)
                print("Completed processing for file: \(fileName)")
                print(output)
            }
            
            activeTasks += 1
        }
        
        // Wait for remaining tasks to finish
        while activeTasks > 0 {
            try await taskGroup.next()
            activeTasks -= 1
        }
    }
    
    print("All files have been processed successfully.")
}

let folderPath = "/Volumes/Samsung_T5/Exodai/Exodai Academy/Exports/SwiftUI Essentials"
let maxConcurrentTasks = 4 // Adjust this number based on your testing

Task {
    do {
        try await transcodeMP4ToHLS(inFolder: folderPath, segmentDuration: 10, maxConcurrentTasks: maxConcurrentTasks)
    } catch {
        print("Error: \(error)")
    }
}
