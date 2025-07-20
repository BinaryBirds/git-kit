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
        ("testRevParse", testRevParse),
        ("testAddAll", testAddAll),
        ("testStatusShort", testStatusShort),
        ("testConfigOperations", testConfigOperations),
        ("testWriteConfigDefaultBranch", testWriteConfigDefaultBranch),
        ("testPushPull", testPushPull),
        ("testBranchOperations", testBranchOperations),
        ("testTagOperations", testTagOperations),
        ("testRemoteOperations", testRemoteOperations),
        ("testSubmoduleOperations", testSubmoduleOperations),
        ("testRevList", testRevList),
        ("testLsRemote", testLsRemote),
        ("testCommitVariations", testCommitVariations),
        ("testLogVariations", testLogVariations),
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


    func testCloneWithDirectory() throws {
        let path = self.currentPath()
        
        let expectation = """
            On branch main
            Your branch is up to date with 'origin/main'.
            
            nothing to commit, working tree clean
            """
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.clone(url: "https://github.com/binarybirds/shell-kit.git", dirName: "MyCustomDirectory"))
        let statusOutput = try git.run("cd \(path)/MyCustomDirectory && git status")
        try self.clean(path: path)
        self.assert(type: "output", result: statusOutput, expected: expectation)
    }

    func testRevParse() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)

        try git.run(.raw("init"))
        try git.run(.commit(message: "initial commit", allowEmpty: true))

        let abbrevRef = try git.run(.revParse(abbrevRef: true, revision: "HEAD"))
        XCTAssertEqual(abbrevRef, "main", "Should return abbreviated reference name")

        let fullSHA = try git.run(.revParse(abbrevRef: false, revision: "HEAD"))
        XCTAssertTrue(fullSHA.count == 40, "Should return full 40-character SHA")
        XCTAssertTrue(fullSHA.allSatisfy { $0.isHexDigit }, "SHA should contain only hex characters")

        let symbolicRef = try git.run(.revParse(abbrevRef: false, revision: "@"))
        XCTAssertEqual(symbolicRef, fullSHA, "Symbolic '@' should resolve to same SHA as HEAD")

        let currentBranch = try git.run(.revParse(abbrevRef: true, revision: "@"))
        XCTAssertEqual(currentBranch, "main", "Should return current branch name")

        try self.clean(path: path)
    }

    func testAddAll() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)

        try git.run(.raw("init"))
        try FileManager.default.createFile(atPath: "\(path)/test.txt", contents: "test content".data(using: .utf8))

        try git.run(.addAll)

        let statusOutput = try git.run(.status())
        XCTAssertTrue(statusOutput.contains("new file"), "File should be staged")
        
        try self.clean(path: path)
    }

    func testStatusShort() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        try FileManager.default.createFile(atPath: "\(path)/file.txt", contents: "test".data(using: .utf8))
        try git.run(.addAll)
        
        // Test status with short flag
        let shortStatus = try git.run(.status(short: true))
        let regularStatus = try git.run(.status(short: false))
        
        // Short status should be more concise
        XCTAssertTrue(shortStatus.count < regularStatus.count, "Short status should be more concise")
        
        try self.clean(path: path)
    }

    func testConfigOperations() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        
        // Test write config using raw commands first to set them up
        try git.run(.raw("config user.name 'Test User'"))
        try git.run(.raw("config user.email 'test@example.com'"))
        
        // Test read config
        let userName = try git.run(.readConfig(name: "user.name"))
        let userEmail = try git.run(.readConfig(name: "user.email"))
        
        XCTAssertEqual(userName, "Test User", "Should read the configured user name")
        XCTAssertEqual(userEmail, "test@example.com", "Should read the configured user email")
        
        try self.clean(path: path)
    }

    func testWriteConfigDefaultBranch() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        
        // Set the default branch name to "myDefaultBranch" using global config
        let globalGit = Git() // No path - will use global config
        try globalGit.run(.raw("config --global init.defaultBranch myDefaultBranch"))
        
        // Now create the directory and git repo (should use the configured default branch)
        let git = Git(path: path)
        try git.run(.raw("init"))
        
        // Make an initial commit so we can check the current branch
        try git.run(.commit(message: "initial commit", allowEmpty: true))
        
        // Ensure that's the branch we're on
        let currentBranch = try git.run(.revParse(abbrevRef: true, revision: "HEAD"))
        XCTAssertEqual(currentBranch, "myDefaultBranch", "Should be on the configured default branch")
        
        // Also verify using git branch command
        let branchOutput = try git.run(.raw("branch"))
        XCTAssertTrue(branchOutput.contains("* myDefaultBranch"), "Should show current branch as myDefaultBranch")
        
        // Reset the git config to remove the custom default branch setting
        // Use --unset-all to handle cases where the config might be set multiple times
        do {
            try globalGit.run(.raw("config --global --unset-all init.defaultBranch"))
        } catch {
            // It's okay if this fails - the config might not exist
        }
        
        // Clean up
        try self.clean(path: path)
    }

    func testPushPull() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        // Clone a repository to have a remote
        try git.run(.clone(url: "https://github.com/binarybirds/shell-kit.git"))
        
        let repoPath = "\(path)/shell-kit"
        let repoGit = Git(path: repoPath)
        
        // Test fetch
        try repoGit.run(.fetch())
        try repoGit.run(.fetch(remote: "origin"))
        try repoGit.run(.fetch(remote: "origin", branch: "main"))
        
        // Test pull variations
        try repoGit.run(.pull())
        try repoGit.run(.pull(remote: "origin"))
        try repoGit.run(.pull(remote: "origin", branch: "main"))
        try repoGit.run(.pull(remote: "origin", branch: "main", rebase: true))
        
        // Note: We can't easily test push without write access, but we can test the command generation
        // by testing the raw value generation
        let pushCommand = Git.Alias.push(remote: "origin", branch: "main")
        XCTAssertEqual(pushCommand.rawValue, "push origin main", "Push command should be properly formatted")
        
        try self.clean(path: path)
    }

    func testBranchOperations() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        try git.run(.commit(message: "initial", allowEmpty: true))
        
        // Test create branch
        try git.run(.create(branch: "feature-branch"))
        
        // Test checkout to new branch
        try git.run(.checkout(branch: "another-branch", create: true))
        
        // Test merge (back to main first)
        try git.run(.checkout(branch: "main"))
        try git.run(.merge(branch: "feature-branch"))
        
        // Test delete branch
        try git.run(.delete(branch: "feature-branch"))
        
        // Verify branch operations worked
        let branchOutput = try git.run(.raw("branch"))
        XCTAssertTrue(branchOutput.contains("another-branch"), "Branch should exist")
        XCTAssertFalse(branchOutput.contains("feature-branch"), "Deleted branch should not exist")
        
        try self.clean(path: path)
    }

    func testTagOperations() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        try git.run(.commit(message: "initial", allowEmpty: true))
        
        // Test tag creation
        try git.run(.tag("v1.0.0"))
        try git.run(.tag("v1.1.0"))
        
        // Verify tags were created
        let tagOutput = try git.run(.raw("tag"))
        XCTAssertTrue(tagOutput.contains("v1.0.0"), "Tag v1.0.0 should exist")
        XCTAssertTrue(tagOutput.contains("v1.1.0"), "Tag v1.1.0 should exist")
        
        try self.clean(path: path)
    }

    func testRemoteOperations() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        
        // Test add remote
        try git.run(.addRemote(name: "origin", url: "https://github.com/test/repo.git"))
        try git.run(.addRemote(name: "upstream", url: "https://github.com/upstream/repo.git"))
        
        // Test rename remote
        try git.run(.renameRemote(oldName: "upstream", newName: "upstream-new"))
        
        // Verify remotes
        let remoteOutput = try git.run(.raw("remote -v"))
        XCTAssertTrue(remoteOutput.contains("origin"), "Origin remote should exist")
        XCTAssertTrue(remoteOutput.contains("upstream-new"), "Renamed remote should exist")
        XCTAssertFalse(remoteOutput.contains("upstream\t"), "Old remote name should not exist")
        
        try self.clean(path: path)
    }

    func testSubmoduleOperations() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        try git.run(.commit(message: "initial", allowEmpty: true))
        
        // Add a submodule
        try git.run(.raw("submodule add https://github.com/binarybirds/shell-kit.git submodules/shell-kit"))
        
        // Test submodule update variations
        try git.run(.submoduleUpdate())
        try git.run(.submoduleUpdate(init: true))
        try git.run(.submoduleUpdate(recursive: true))
        try git.run(.submoduleUpdate(init: true, recursive: true, rebase: true))
        
        // Test submodule foreach
        try git.run(.submoduleForeach(recursive: false, command: "pwd"))
        try git.run(.submoduleForeach(recursive: true, command: "git status"))
        
        try self.clean(path: path)
    }

    func testRevList() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        try git.run(.commit(message: "first", allowEmpty: true))
        try git.run(.commit(message: "second", allowEmpty: true))
        
        let commitCount = try git.run(.revList(branch: "HEAD", count: true))
        let commitList = try git.run(.revList(branch: "HEAD"))
        let commitRange = try git.run(.revList(branch: "HEAD", revisions: "HEAD~1"))
        
        XCTAssertEqual(commitCount.trimmingCharacters(in: .whitespacesAndNewlines), "2", "Should have 2 commits")
        XCTAssertTrue(commitList.contains("\n"), "Should list multiple commits")
        XCTAssertFalse(commitRange.isEmpty, "Should return commit range")
        
        try self.clean(path: path)
    }

    func testLsRemote() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        try git.run(.raw("config user.name 'Test User'"))
        try git.run(.raw("config user.email 'test@example.com'"))
        
        try git.run(.raw("commit -m 'initial commit' --allow-empty --no-gpg-sign"))
        
        try git.run(.raw("checkout -b feature/test-feature"))
        try git.run(.raw("commit -m 'feature commit' --allow-empty --no-gpg-sign"))
        
        try git.run(.raw("checkout -b develop"))
        try git.run(.raw("commit -m 'develop commit' --allow-empty --no-gpg-sign"))
        
        try git.run(.raw("checkout main"))
        try git.run(.raw("tag v1.0.0"))
        try git.run(.raw("tag v1.1.0"))
        
        let currentDirectory = FileManager.default.currentDirectoryPath
        let absolutePath = "\(currentDirectory)/\(path)"
        let remoteRefs = try git.run(.lsRemote(url: absolutePath))
        let headsOnly = try git.run(.lsRemote(url: absolutePath, limitToHeads: true))
        
        XCTAssertTrue(remoteRefs.contains("refs/heads/main"), "Should contain main branch")
        XCTAssertTrue(remoteRefs.contains("refs/heads/feature/test-feature"), "Should contain feature branch")
        XCTAssertTrue(remoteRefs.contains("refs/heads/develop"), "Should contain develop branch")
        
        XCTAssertTrue(remoteRefs.contains("refs/tags/v1.0.0"), "Should contain v1.0.0 tag")
        XCTAssertTrue(remoteRefs.contains("refs/tags/v1.1.0"), "Should contain v1.1.0 tag")
        
        XCTAssertTrue(headsOnly.contains("refs/heads/main"), "Heads-only should contain main branch")
        XCTAssertTrue(headsOnly.contains("refs/heads/feature/test-feature"), "Heads-only should contain feature branch")
        XCTAssertTrue(headsOnly.contains("refs/heads/develop"), "Heads-only should contain develop branch")
        XCTAssertFalse(headsOnly.contains("refs/tags/"), "Heads-only should NOT contain tags")
        
        let headsOnlyLines = headsOnly.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        let fullRefsLines = remoteRefs.components(separatedBy: CharacterSet.newlines).filter { !$0.isEmpty }
        XCTAssertTrue(headsOnlyLines.count < fullRefsLines.count, "Heads-only should have fewer refs than full listing")
        XCTAssertEqual(headsOnlyLines.count, 3, "Should have exactly 3 branches")
        XCTAssertTrue(fullRefsLines.count >= 5, "Full refs should include branches and tags")
        
        try self.clean(path: path)
    }

    func testCommitVariations() throws {
        let signedCommitAlias = Git.Alias.commit(message: "test signed", allowEmpty: true, gpgSigned: true)
        XCTAssertTrue(signedCommitAlias.rawValue.contains("--gpg-sign"), "GPG signed commit should include --gpg-sign flag")
        XCTAssertFalse(signedCommitAlias.rawValue.contains("--no-gpg-sign"), "GPG signed commit should NOT include --no-gpg-sign flag")
        
        let unsignedCommitAlias = Git.Alias.commit(message: "test unsigned", allowEmpty: true, gpgSigned: false)
        XCTAssertTrue(unsignedCommitAlias.rawValue.contains("--no-gpg-sign"), "Unsigned commit should include --no-gpg-sign flag")
        XCTAssertFalse(unsignedCommitAlias.rawValue.contains("--gpg-sign"), "Unsigned commit should NOT include --gpg-sign flag")
    }

    func testLogVariations() throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try git.run(.raw("init"))
        try git.run(.commit(message: "first commit", allowEmpty: true))
        try git.run(.commit(message: "second commit", allowEmpty: true))
        try git.run(.commit(message: "third commit", allowEmpty: true))

        let limitedLog = try git.run(.log(numberOfCommits: 2))
        let fullLog = try git.run(.log())
        let onelineLog = try git.run(.log(options: ["--oneline"]))
        let prettyLog = try git.run(.log(numberOfCommits: 1, options: ["--pretty=format:%s"]))
        let singleCommitLog = try git.run(.log(numberOfCommits: 1))

        XCTAssertTrue(limitedLog.contains("third commit"), "Limited log should contain third commit")
        XCTAssertTrue(limitedLog.contains("second commit"), "Limited log should contain second commit")
        XCTAssertFalse(limitedLog.contains("first commit"), "Limited log should NOT contain first commit")
        XCTAssertTrue(limitedLog.contains("commit "), "Limited log should contain full commit format")
        XCTAssertTrue(limitedLog.contains("Author:"), "Limited log should contain author info")
        XCTAssertTrue(limitedLog.contains("Date:"), "Limited log should contain date info")
        
        XCTAssertTrue(fullLog.contains("first commit"), "Full log should contain first commit")
        XCTAssertTrue(fullLog.contains("second commit"), "Full log should contain second commit")
        XCTAssertTrue(fullLog.contains("third commit"), "Full log should contain third commit")
        XCTAssertTrue(fullLog.count > limitedLog.count, "Full log should be longer than limited log")
        
        XCTAssertTrue(onelineLog.contains("first commit"), "Oneline log should contain first commit")
        XCTAssertTrue(onelineLog.contains("second commit"), "Oneline log should contain second commit")
        XCTAssertTrue(onelineLog.contains("third commit"), "Oneline log should contain third commit")
        XCTAssertFalse(onelineLog.contains("Author:"), "Oneline log should NOT contain author info")
        XCTAssertFalse(onelineLog.contains("Date:"), "Oneline log should NOT contain date info")
        // Oneline format should be much more compact
        XCTAssertTrue(onelineLog.count < fullLog.count / 2, "Oneline log should be much shorter than full log")
        
        XCTAssertEqual(prettyLog.trimmingCharacters(in: .whitespacesAndNewlines), "third commit", "Pretty log should contain only the commit message")
        XCTAssertFalse(prettyLog.contains("commit "), "Pretty log should NOT contain commit hash")
        XCTAssertFalse(prettyLog.contains("Author:"), "Pretty log should NOT contain author info")
        XCTAssertFalse(prettyLog.contains("Date:"), "Pretty log should NOT contain date info")
        
        XCTAssertTrue(singleCommitLog.contains("third commit"), "Single commit log should contain latest commit")
        XCTAssertFalse(singleCommitLog.contains("second commit"), "Single commit log should NOT contain second commit")
        XCTAssertFalse(singleCommitLog.contains("first commit"), "Single commit log should NOT contain first commit")
        
        try self.clean(path: path)
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
