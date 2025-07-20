/**
    GitKitTests.swift
    GitKitTests
 
    Created by Tibor Bödecs on 2019.01.02.
    Copyright Binary Birds. All rights reserved.
 */

import XCTest
@testable import GitKit

extension String {
    func snakeCased() -> String? {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: self.count)
        return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1-$2").lowercased()
    }
}

final class GitKitTests: XCTestCase {

    static var allTests = [
        ("testInit", testInit),
        ("testLog", testLog),
        ("testCommandWithArgs", testCommandWithArgs),
        ("testClone", testClone),
    ]
    
    // MARK: - helpers
    
    private func currentPath(for function: String = #function) -> String {
        return "./git-" + String(function.dropLast().dropLast()).snakeCased()!
    }

    private func assert<T: Equatable>(type: String, result: T, expected: T) {
        XCTAssertEqual(result, expected, "Invalid \(type) `\(result)`, expected `\(expected)`.")
    }

    private func clean(path: String) throws {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue == true {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    private func _test(_ alias: Git.Alias, path: String, expectation: String) throws {
        let path = path
        try self.clean(path: path)
        let expectedOutput = expectation
        let git = Git(path: path)
        try git.run(.raw("init && git commit -m 'initial' --allow-empty --no-gpg-sign"))
        let output = try git.run(alias)
        self.assert(type: "output", result: output, expected: expectedOutput)
        try self.clean(path: path)
    }

    // MARK: - test functions

    func testInit() throws {
        let path = self.currentPath()
        let expectation = "Initialized empty Git repository in"
        try self.clean(path: path)
        let git = Git(path: path)
        let out = try git.run(.cmd(.initialize))
        try self.clean(path: path)
        XCTAssertTrue(out.hasPrefix(expectation), "Repository was not created.")
    }
    
    func testLog() throws {
        let path = self.currentPath()
        let expectation = "Hello world!"
        try self.clean(path: path)
        let git = Git(path: path)
        try git.run(.cmd(.initialize))
        try git.run(.commit(message: expectation, allowEmpty: true))
        let out = try git.run(.log(numberOfCommits: 1))
        try self.clean(path: path)
        XCTAssertTrue(out.hasSuffix(expectation), "Commit was not created.")
    }
    
    func testCommandWithArgs() throws {
        let path = self.currentPath()

        try self._test(.cmd(.branch, "-a"), path: path, expectation: "* main")
    }
    
    func testClone() throws {
        let path = self.currentPath()
        
        let expectation = """
            On branch main
            Your branch is up to date with 'origin/main'.

            nothing to commit, working tree clean
            """

        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.clone(url: "https://github.com/binarybirds/shell-kit.git"))
        let statusOutput = try git.run("cd \(path)/shell-kit && git status")
        try self.clean(path: path)
        self.assert(type: "output", result: statusOutput, expected: expectation)
    }

    #if os(macOS)
    func testAsyncRun() throws {
        let path = self.currentPath()
        try self.clean(path: path)
        let expectedOutput = """
            On branch main
            nothing to commit, working tree clean
            """
        
        let git = Git(path: path)
        try git.run(.raw("init && git commit -m 'initial' --allow-empty --no-gpg-sign"))
        
        let expectation = XCTestExpectation(description: "Shell command finished.")
        git.run(.cmd(.status)) { result, error in
            if let error = error {
                try? self.clean(path: path)
                return XCTFail("There should be no errors. (error: `\(error.localizedDescription)`)")
            }
            guard let output = result else {
                try? self.clean(path: path)
                return XCTFail("Empty result, expected `\(expectedOutput)`.")
            }
            self.assert(type: "output", result: output, expected: expectedOutput)
            try? self.clean(path: path)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 5)
    }
    #endif
}
