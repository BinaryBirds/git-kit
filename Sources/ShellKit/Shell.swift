/**
    Shell.swift
    ShellKit
 
    Created by Tibor Bödecs on 2018.12.31.
    Copyright Binary Birds. All rights reserved.
 */

import Foundation
import Dispatch

#if os(macOS)
private extension FileHandle {

    // checks if the FileHandle is a standard one (STDOUT, STDIN, STDERR)
    var isStandard: Bool {
        return self === FileHandle.standardOutput ||
            self === FileHandle.standardError ||
            self === FileHandle.standardInput
    }
}

// shell data handler protocol
public protocol ShellDataHandler {
    
    // called each time there is new data available
    func handle(_ data: Data)
    
    // optional method called on the end of the execution process
    func end()
}

public extension ShellDataHandler {

    func end() {
        // default implementation: do nothing...
    }
}

extension FileHandle: ShellDataHandler {

    public func handle(_ data: Data) {
        self.write(data)
    }

    public func end() {
        guard !self.isStandard else {
            return
        }
        self.closeFile()
    }
}
#endif

// a custom shell representation object
open class Shell {
    
    // shell errors
    public enum Error: LocalizedError {
        // invalid shell output data error
        case outputData
        // generic shell error, the first parameter is the error code, the second is the error message
        case generic(Int, String)
        
        public var errorDescription: String? {
            switch self {
            case .outputData:
                return "Invalid or empty shell output."
            case .generic(let code, let message):
                return message + " (code: \(code))"
            }
        }
    }
    
    // lock queue to keep data writes in sync
    private let lockQueue: DispatchQueue

    // type of the shell, by default: /bin/sh
    public var type: String
    
    // custom env variables exposed for the shell
    public var env: [String: String]

    #if os(macOS)
    // output data handler
    public var outputHandler: ShellDataHandler?

    // error data handler
    public var errorHandler: ShellDataHandler?
    #endif

    /**
        Initializes a new Shell object
     
        - Parameters:
            - type: The type of the shell, default: /bin/sh
        - env: Additional environment variables for the shell, default: empty
     
     */
    public init(_ type: String = "/bin/sh", env: [String: String] = [:]) {
        self.lockQueue = DispatchQueue(label: "shellkit.lock.queue")
        self.type = type
        self.env = env
    }

    /**
        Runs a specific command through the current shell.
     
        - Parameters:
            - command: The command to be executed
     
        - Throws:
            `Shell.Error.outputData` if the command execution succeeded but the output is empty,
            otherwise `Shell.Error.generic(Int, String)` where the first parameter is the exit code,
            the second is the error message
     
        - Returns: The output string of the command without trailing newlines
     */
    @discardableResult
    public func run(_ command: String) throws -> String {
        let process = Process()
        process.launchPath = self.type
        process.arguments = ["-c", command]
        
        if !self.env.isEmpty {
            process.environment = ProcessInfo.processInfo.environment
            self.env.forEach { variable in
                process.environment?[variable.key] = variable.value
            }
        }

        var outputData = Data()
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
            
        var errorData = Data()
        let errorPipe = Pipe()
        process.standardError = errorPipe
            
        #if os(macOS)
        outputPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            self.lockQueue.async {
                outputData.append(data)
                self.outputHandler?.handle(data)
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            self.lockQueue.async {
                errorData.append(data)
                self.errorHandler?.handle(data)
            }
        }
        #endif
        
        process.launch()
        
        #if os(Linux)
        self.lockQueue.sync {
            outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        }
        #endif
        
        process.waitUntilExit()

        #if os(macOS)
        self.outputHandler?.end()
        self.errorHandler?.end()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        #endif
        
        return try self.lockQueue.sync {
            guard process.terminationStatus == 0 else {
                var message = "Unknown error"
                if let error = String(data: errorData, encoding: .utf8) {
                    message = error.trimmingCharacters(in: .newlines)
                }
                throw Error.generic(Int(process.terminationStatus), message)
            }
            guard let output = String(data: outputData, encoding: .utf8) else {
                throw Error.outputData
            }
            return output.trimmingCharacters(in: .newlines)
        }
    }
    
    /**
        Async version of the run command
     
        - Parameters:
            - command: The command to be executed
            - completion: The completion block with the output and error

        The command will be executed on a concurrent dispatch queue.
     */
    public func run(_ command: String, completion: @escaping ((String?, Swift.Error?) -> Void)) {
        let queue = DispatchQueue(label: "shellkit.process.queue", attributes: .concurrent)
        queue.async {
            do {
                let output = try self.run(command)
                completion(output, nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }
}
