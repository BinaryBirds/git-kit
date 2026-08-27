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

    private func _test(_ alias: Git.Alias, path: String, expectation: String) async throws {
        let path = path
        try self.clean(path: path)
        let expectedOutput = expectation
        let git = Git(path: path)
        try await git.run(.raw("init && git commit -m 'initial' --allow-empty --no-gpg-sign"))
        let output = try await git.run(alias)
        self.assert(type: "output", result: output, expected: expectedOutput)
        try self.clean(path: path)
    }

    // MARK: - test functions

    func testInit() async throws {
        let path = self.currentPath()
        let expectation = "Initialized empty Git repository in"
        try self.clean(path: path)
        let git = Git(path: path)
        let out = try await git.run(.cmd(.initialize))
        try self.clean(path: path)
        XCTAssertTrue(out.hasPrefix(expectation), "Repository was not created.")
    }
    
    func testLog() async throws {
        let path = self.currentPath()
        let expectation = "Hello world!"
        try self.clean(path: path)
        let git = Git(path: path)
        try await git.run(.cmd(.initialize))
        try await git.run(.commit(message: expectation, allowEmpty: true))
        let out = try await git.run(.log(numberOfCommits: 1))
        try self.clean(path: path)
        XCTAssertTrue(out.hasSuffix(expectation), "Commit was not created.")
    }
    
    func testCommandWithArgs() async throws {
        let path = self.currentPath()

        try await self._test(.cmd(.branch, "-a"), path: path, expectation: "* main")
    }
    
    func testClone() async throws {
        let basePath = self.currentPath()
        let currentDirectory = FileManager.default.currentDirectoryPath
        let sourcePath = "\(currentDirectory)/\(basePath)-source"
        let clonePath = "\(currentDirectory)/\(basePath)-clone"
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
        
        let sourceGit = Git(path: sourcePath)
        try await sourceGit.run(.raw("init"))
        try await sourceGit.run(.raw("config user.name 'Test User'"))
        try await sourceGit.run(.raw("config user.email 'test@example.com'"))
        try await sourceGit.run(.raw("commit -m 'initial commit' --allow-empty --no-gpg-sign"))
        
        let git = Git(path: clonePath)
        try await git.run(.clone(url: sourcePath))
        
        let clonedRepoName = try XCTUnwrap(sourcePath.components(separatedBy: "/").last)
        let statusOutput = try await git.run("cd \(clonePath)/\(clonedRepoName) && git status")
        XCTAssertTrue(statusOutput.contains("On branch main"), "Should be on main branch")
        XCTAssertTrue(statusOutput.contains("nothing to commit"), "Should be clean working directory")
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
    }

    func testCloneWithDirectory() async throws {
        let basePath = self.currentPath()
        let currentDirectory = FileManager.default.currentDirectoryPath
        let sourcePath = "\(currentDirectory)/\(basePath)-source"
        let clonePath = "\(currentDirectory)/\(basePath)-clone"
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
        
        let sourceGit = Git(path: sourcePath)
        try await sourceGit.run(.raw("init"))
        try await sourceGit.run(.raw("config user.name 'Test User'"))
        try await sourceGit.run(.raw("config user.email 'test@example.com'"))
        try await sourceGit.run(.raw("commit -m 'initial commit' --allow-empty --no-gpg-sign"))
        
        let git = Git(path: clonePath)
        try await git.run(.clone(url: sourcePath, dirName: "MyCustomDirectory"))
        
        let statusOutput = try await git.run("cd \(clonePath)/MyCustomDirectory && git status")
        XCTAssertTrue(statusOutput.contains("On branch main"), "Should be on main branch")
        XCTAssertTrue(statusOutput.contains("nothing to commit"), "Should be clean working directory")
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
    }

    func testCheckoutRemoteTracking() async throws {
        let basePath = self.currentPath()
        let currentDirectory = FileManager.default.currentDirectoryPath
        let sourcePath = "\(currentDirectory)/\(basePath)-source"
        let clonePath = "\(currentDirectory)/\(basePath)-clone"
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
        
        let sourceGit = Git(path: sourcePath)
        try await sourceGit.run(.raw("init"))
        try await sourceGit.run(.raw("config user.name 'Test User'"))
        try await sourceGit.run(.raw("config user.email 'test@example.com'"))
        try await sourceGit.run(.raw("commit -m 'initial commit' --allow-empty --no-gpg-sign"))
        
        let git = Git(path: clonePath)
        try await git.run(.clone(url: sourcePath))
        
        let clonedRepoName = try XCTUnwrap(sourcePath.components(separatedBy: "/").last)
        let repoPath = "\(clonePath)/\(clonedRepoName)"
        let repoGit = Git(path: repoPath)

        try await repoGit.run(.checkout(branch: "feature-branch", create: true, tracking: "origin/main"))
        let branchOutput = try await repoGit.run(.raw("branch -vv"))
        
        XCTAssertTrue(branchOutput.contains("feature-branch"), "New branch should be created")
        XCTAssertTrue(branchOutput.contains("origin/main"), "Branch should track origin/main")
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
    }

    func testRevParse() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)

        try await git.run(.raw("init"))
        try await git.run(.commit(message: "initial commit", allowEmpty: true))

        let abbrevRef = try await git.run(.revParse(abbrevRef: true, revision: "HEAD"))
        XCTAssertEqual(abbrevRef, "main", "Should return abbreviated reference name")

        let fullSHA = try await git.run(.revParse(abbrevRef: false, revision: "HEAD"))
        XCTAssertTrue(fullSHA.count == 40, "Should return full 40-character SHA")
        XCTAssertTrue(fullSHA.allSatisfy { $0.isHexDigit }, "SHA should contain only hex characters")

        let symbolicRef = try await git.run(.revParse(abbrevRef: false, revision: "@"))
        XCTAssertEqual(symbolicRef, fullSHA, "Symbolic '@' should resolve to same SHA as HEAD")

        let currentBranch = try await git.run(.revParse(abbrevRef: true, revision: "@"))
        XCTAssertEqual(currentBranch, "main", "Should return current branch name")

        try self.clean(path: path)
    }

    func testAddAll() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)

        try await git.run(.raw("init"))
        FileManager.default.createFile(atPath: "\(path)/test.txt", contents: "test content".data(using: .utf8))

        try await git.run(.addAll)

        let statusOutput = try await git.run(.status())
        XCTAssertTrue(statusOutput.contains("new file"), "File should be staged")
        
        try self.clean(path: path)
    }

    func testStatusShort() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try await git.run(.raw("init"))
        FileManager.default.createFile(atPath: "\(path)/file.txt", contents: "test".data(using: .utf8))
        try await git.run(.addAll)
        
        let shortStatus = try await git.run(.status(short: true))
        let regularStatus = try await git.run(.status(short: false))
        
        XCTAssertTrue(shortStatus.count < regularStatus.count, "Short status should be more concise")
        
        try self.clean(path: path)
    }

    func testGitConfig() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        
        let git = Git(path: path)
        try await git.run(.raw("init"))
        
        try await git.run(.writeConfig(name: "user.name", value: "\"Test User GitKit\""))
        try await git.run(.writeConfig(name: "user.email", value: "test@gitkit.example.com"))
        try await git.run(.writeConfig(name: "core.editor", value: "vim"))
        
        let userName = try await git.run(.readConfig(name: "user.name"))
        let userEmail = try await git.run(.readConfig(name: "user.email"))
        let coreEditor = try await git.run(.readConfig(name: "core.editor"))
        
        XCTAssertEqual(userName.trimmingCharacters(in: .whitespacesAndNewlines), "Test User GitKit", "User name should be set correctly")
        XCTAssertEqual(userEmail.trimmingCharacters(in: .whitespacesAndNewlines), "test@gitkit.example.com", "User email should be set correctly")
        XCTAssertEqual(coreEditor.trimmingCharacters(in: .whitespacesAndNewlines), "vim", "Core editor should be set correctly")
        
        try await git.run(.commit(message: "test commit", allowEmpty: true))
        
        let logOutput = try await git.run(.raw("log --format='%an <%ae>' -1"))
        XCTAssertTrue(logOutput.contains("Test User GitKit <test@gitkit.example.com>"), "Commit should use the configured user information")
        
        try await git.run(.writeConfig(name: "user.name", value: "\"Updated User\""))
        let updatedUserName = try await git.run(.readConfig(name: "user.name"))
        XCTAssertTrue(updatedUserName.contains("Updated User"), "Should be able to update existing config values")
        
        try self.clean(path: path)
    }

    func testPushPull() async throws {
        let basePath = self.currentPath()
        let currentDirectory = FileManager.default.currentDirectoryPath
        let sourcePath = "\(currentDirectory)/\(basePath)-source"
        let clonePath = "\(currentDirectory)/\(basePath)-clone"
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
        
        let sourceGit = Git(path: sourcePath)
        try await sourceGit.run(.raw("init"))
        try await sourceGit.run(.raw("config user.name 'Test User'"))
        try await sourceGit.run(.raw("config user.email 'test@example.com'"))
        try await sourceGit.run(.raw("commit -m 'initial commit' --allow-empty --no-gpg-sign"))
        
        let git = Git(path: clonePath)
        try await git.run(.clone(url: sourcePath))
        
        let clonedRepoName = try XCTUnwrap(sourcePath.components(separatedBy: "/").last)
        let repoPath = "\(clonePath)/\(clonedRepoName)"
        let repoGit = Git(path: repoPath)
        
        try await repoGit.run(.fetch())
        try await repoGit.run(.fetch(remote: "origin"))
        try await repoGit.run(.fetch(remote: "origin", branch: "main"))
        
        try await repoGit.run(.pull())
        try await repoGit.run(.pull(remote: "origin"))
        try await repoGit.run(.pull(remote: "origin", branch: "main"))
        try await repoGit.run(.pull(remote: "origin", branch: "main", rebase: true))
        
        let pushCommand = Git.Alias.push(remote: "origin", branch: "main")
        XCTAssertEqual(pushCommand.rawValue, "push origin main", "Push command should be properly formatted")
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
    }

    func testBranchOperations() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try await git.run(.raw("init"))
        try await git.run(.commit(message: "initial", allowEmpty: true))
        
        try await git.run(.create(branch: "feature-branch"))
        
        try await git.run(.checkout(branch: "another-branch", create: true))
        
        try await git.run(.checkout(branch: "main"))
        try await git.run(.merge(branch: "feature-branch"))
        
        try await git.run(.delete(branch: "feature-branch"))
        
        let branchOutput = try await git.run(.raw("branch"))
        XCTAssertTrue(branchOutput.contains("another-branch"), "Branch should exist")
        XCTAssertFalse(branchOutput.contains("feature-branch"), "Deleted branch should not exist")
        
        try self.clean(path: path)
    }

    func testTagOperations() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try await git.run(.raw("init"))
        try await git.run(.commit(message: "initial", allowEmpty: true))
        
        try await git.run(.tag("v1.0.0"))
        try await git.run(.tag("v1.1.0"))
        
        let tagOutput = try await git.run(.raw("tag"))
        XCTAssertTrue(tagOutput.contains("v1.0.0"), "Tag v1.0.0 should exist")
        XCTAssertTrue(tagOutput.contains("v1.1.0"), "Tag v1.1.0 should exist")
        
        try self.clean(path: path)
    }

    func testRemoteOperations() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try await git.run(.raw("init"))

        try await git.run(.addRemote(name: "origin", url: "https://github.com/test/repo.git"))
        try await git.run(.addRemote(name: "upstream", url: "https://github.com/upstream/repo.git"))
        
        try await git.run(.renameRemote(oldName: "upstream", newName: "upstream-new"))
        
        let remoteOutput = try await git.run(.raw("remote -v"))
        XCTAssertTrue(remoteOutput.contains("origin"), "Origin remote should exist")
        XCTAssertTrue(remoteOutput.contains("upstream-new"), "Renamed remote should exist")
        XCTAssertFalse(remoteOutput.contains("upstream\t"), "Old remote name should not exist")
        
        try self.clean(path: path)
    }

    func testSubmoduleOperations() async throws {
        let basePath = self.currentPath()
        let currentDirectory = FileManager.default.currentDirectoryPath
        let mainRepoPath = "\(currentDirectory)/\(basePath)-main"
        let submoduleRepoPath = "\(currentDirectory)/\(basePath)-submodule"
        
        try self.clean(path: mainRepoPath)
        try self.clean(path: submoduleRepoPath)
        
        let submoduleGit = Git(path: submoduleRepoPath)
        try await submoduleGit.run(.raw("init"))
        try await submoduleGit.run(.raw("config user.name 'Test User'"))
        try await submoduleGit.run(.raw("config user.email 'test@example.com'"))
        try await submoduleGit.run(.raw("commit -m 'submodule initial commit' --allow-empty --no-gpg-sign"))
        
        // Save the current global config value (if any) and set it temporarily
        let git = Git(path: mainRepoPath)
        var originalConfigValue: String?
        do {
            originalConfigValue = try await git.run(.raw("config --global --get protocol.file.allow"))
        } catch {
            // Config doesn't exist, which is fine
            originalConfigValue = nil
        }
        
        try await git.run(.raw("init"))
        try await git.run(.raw("config user.name 'Test User'"))
        try await git.run(.raw("config user.email 'test@example.com'"))
        
        // Set the protocol.file.allow config temporarily
        try await git.run(.raw("config --global protocol.file.allow always"))
        
        try await git.run(.commit(message: "initial", allowEmpty: true))
        
        try await git.run(.raw("submodule add \(submoduleRepoPath) submodules/test-submodule"))
        
        try await git.run(.submoduleUpdate())
        try await git.run(.submoduleUpdate(init: true))
        try await git.run(.submoduleUpdate(recursive: true))
        try await git.run(.submoduleUpdate(init: true, recursive: true, rebase: true))
        
        try await git.run(.submoduleForeach(recursive: false, command: "pwd"))
        try await git.run(.submoduleForeach(recursive: true, command: "git status"))
        
        let statusOutput = try await git.run(.raw("submodule status"))
        XCTAssertTrue(statusOutput.contains("test-submodule"), "Submodule should be listed in status")
        
        // Restore the original global config value
        if let originalValue = originalConfigValue {
            try await git.run(.raw("config --global protocol.file.allow \(originalValue)"))
        } else {
            // Config didn't exist before, so remove it
            _ = try? await git.run(.raw("config --global --unset protocol.file.allow"))
        }
        
        try self.clean(path: mainRepoPath)
        try self.clean(path: submoduleRepoPath)
    }

    func testRevList() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        git.verbose = true

        try await git.run(.raw("init"))
        try await git.run(.commit(message: "first", allowEmpty: true))
        try await git.run(.commit(message: "second", allowEmpty: true))
        
        let commitCount = try await git.run(.revList(count: true, revisions: "HEAD"))
        let commitList = try await git.run(.revList(revisions: "HEAD"))
        let commitRange = try await git.run(.revList(revisions: "HEAD HEAD~1"))

        XCTAssertEqual(commitCount.trimmingCharacters(in: .whitespacesAndNewlines), "2", "Should have 2 commits")
        XCTAssertTrue(commitList.contains("\n"), "Should list multiple commits")
        XCTAssertFalse(commitRange.isEmpty, "Should return commit range")
        
        try self.clean(path: path)
    }

    func testLsRemote() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        
        let git = Git(path: path)
        
        try await git.run(.raw("init"))
        try await git.run(.raw("config user.name 'Test User'"))
        try await git.run(.raw("config user.email 'test@example.com'"))
        
        try await git.run(.raw("commit -m 'initial commit' --allow-empty --no-gpg-sign"))
        
        try await git.run(.raw("checkout -b feature/test-feature"))
        try await git.run(.raw("commit -m 'feature commit' --allow-empty --no-gpg-sign"))
        
        try await git.run(.raw("checkout -b develop"))
        try await git.run(.raw("commit -m 'develop commit' --allow-empty --no-gpg-sign"))
        
        try await git.run(.raw("checkout main"))
        try await git.run(.raw("tag v1.0.0"))
        try await git.run(.raw("tag v1.1.0"))
        
        let currentDirectory = FileManager.default.currentDirectoryPath
        let absolutePath = "\(currentDirectory)/\(path)"
        let remoteRefs = try await git.run(.lsRemote(url: absolutePath))
        let headsOnly = try await git.run(.lsRemote(url: absolutePath, limitToHeads: true))
        
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

    func testCommitVariations() async throws {
        let signedCommitAlias = Git.Alias.commit(message: "test signed", allowEmpty: true, gpgSigned: true)
        XCTAssertTrue(signedCommitAlias.rawValue.contains("--gpg-sign"), "GPG signed commit should include --gpg-sign flag")
        XCTAssertFalse(signedCommitAlias.rawValue.contains("--no-gpg-sign"), "GPG signed commit should NOT include --no-gpg-sign flag")
        
        let unsignedCommitAlias = Git.Alias.commit(message: "test unsigned", allowEmpty: true, gpgSigned: false)
        XCTAssertTrue(unsignedCommitAlias.rawValue.contains("--no-gpg-sign"), "Unsigned commit should include --no-gpg-sign flag")
        XCTAssertFalse(unsignedCommitAlias.rawValue.contains("--gpg-sign"), "Unsigned commit should NOT include --gpg-sign flag")
    }

    func testLogVariations() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)
        
        try await git.run(.raw("init"))
        try await git.run(.commit(message: "first commit", allowEmpty: true))
        try await git.run(.commit(message: "second commit", allowEmpty: true))
        try await git.run(.commit(message: "third commit", allowEmpty: true))

        let limitedLog = try await git.run(.log(numberOfCommits: 2))
        let fullLog = try await git.run(.log())
        let onelineLog = try await git.run(.log(options: ["--oneline"]))
        let prettyLog = try await git.run(.log(numberOfCommits: 1, options: ["--pretty=format:%s"]))
        let singleCommitLog = try await git.run(.log(numberOfCommits: 1))

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

    func testLogWithRevisions() async throws {
        let path = self.currentPath()
        
        try self.clean(path: path)
        let git = Git(path: path)

        try await git.run(.raw("init"))
        try await git.run(.commit(message: "first commit", allowEmpty: true))
        try await git.run(.commit(message: "second commit", allowEmpty: true))
        try await git.run(.commit(message: "third commit", allowEmpty: true))

        let logWithRevisions = try await git.run(.log(revisions: "@^^..@^"))

        XCTAssertTrue(logWithRevisions.contains("second commit"), "Log with @^^..@^ revision should contain second commit")
        XCTAssertFalse(logWithRevisions.contains("first commit"), "Log with @^^..@^ revision should NOT contain first commit")
        XCTAssertFalse(logWithRevisions.contains("third commit"), "Log with @^^..@^ revision should NOT contain third commit")
        
        try self.clean(path: path)
    }

    func testPathsWithSpaces() async throws {
        let basePath = self.currentPath()
        let pathWithSpaces = "\(basePath) with spaces"
        
        try self.clean(path: pathWithSpaces)
        
        let git = Git(path: pathWithSpaces)
        
        // Test basic operations in a path with spaces
        try await git.run(.raw("init"))
        try await git.run(.raw("config user.name 'Test User'"))
        try await git.run(.raw("config user.email 'test@example.com'"))
        
        // Create a file and test git operations
        FileManager.default.createFile(atPath: "\(pathWithSpaces)/test file.txt", contents: "test content".data(using: .utf8))
        
        try await git.run(.addAll)
        let statusOutput = try await git.run(.status(short: true))
        XCTAssertTrue(statusOutput.contains("A"), "File should be staged")
        
        try await git.run(.commit(message: "test commit with spaces in path", allowEmpty: false))
        
        let logOutput = try await git.run(.log(numberOfCommits: 1, options: ["--oneline"]))
        XCTAssertTrue(logOutput.contains("test commit with spaces in path"), "Commit should be successful")
        
        // Test status after commit
        let cleanStatus = try await git.run(.status(short: true))
        XCTAssertTrue(cleanStatus.isEmpty, "Working directory should be clean after commit")
        
        try self.clean(path: pathWithSpaces)
    }

    func testCloneWithSpacesInDirectoryName() async throws {
        let basePath = self.currentPath()
        let currentDirectory = FileManager.default.currentDirectoryPath
        let sourcePath = "\(currentDirectory)/\(basePath)-source"
        let clonePath = "\(currentDirectory)/\(basePath) clone path"
        let targetDirName = "repo with spaces"
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
        
        // Create source repository
        let sourceGit = Git(path: sourcePath)
        try await sourceGit.run(.raw("init"))
        try await sourceGit.run(.raw("config user.name 'Test User'"))
        try await sourceGit.run(.raw("config user.email 'test@example.com'"))
        try await sourceGit.run(.raw("commit -m 'initial commit' --allow-empty --no-gpg-sign"))
        
        // Test cloning into a path with spaces
        let git = Git(path: clonePath)
        try await git.run(.clone(url: sourcePath, dirName: targetDirName))
        
        // Verify the clone was successful
        let clonedRepoPath = "\(clonePath)/\(targetDirName)"
        XCTAssertTrue(FileManager.default.fileExists(atPath: clonedRepoPath), "Cloned repository should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(clonedRepoPath)/.git"), "Cloned repository should have .git directory")
        
        // Test git operations in the cloned repo with spaces in path
        let clonedGit = Git(path: clonedRepoPath)
        let statusOutput = try await clonedGit.run(.status())
        XCTAssertTrue(statusOutput.contains("On branch main"), "Should be on main branch")
        XCTAssertTrue(statusOutput.contains("nothing to commit"), "Should be clean working directory")
        
        // Test creating and committing a file with spaces in the repo path
        FileManager.default.createFile(atPath: "\(clonedRepoPath)/file with spaces.txt", contents: "content".data(using: .utf8))
        try await clonedGit.run(.addAll)
        try await clonedGit.run(.commit(message: "add file with spaces"))
        
        let logOutput = try await clonedGit.run(.log(numberOfCommits: 1, options: ["--oneline"]))
        XCTAssertTrue(logOutput.contains("add file with spaces"), "New commit should exist")
        
        try self.clean(path: sourcePath)
        try self.clean(path: clonePath)
    }

    /// Replaces the former completion-handler `testAsyncRun`; the block-based
    /// variant was removed in 2.0, so the same behaviour is covered via async.
    func testAsyncRun() async throws {
        let path = self.currentPath()
        try self.clean(path: path)
        let expectedOutput = """
            On branch main
            nothing to commit, working tree clean
            """

        let git = Git(path: path)
        try await git.run(.raw("init && git commit -m 'initial' --allow-empty --no-gpg-sign"))
        let output = try await git.run(.cmd(.status))
        self.assert(type: "output", result: output, expected: expectedOutput)
        try self.clean(path: path)
    }

}
