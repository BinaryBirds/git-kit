/**
    Git.swift
    GitKit
 
    Created by Tibor Bödecs on 2019.01.02.
    Copyright Binary Birds. All rights reserved.
 */

import ShellKit

/// a Git wrapper class
public final class Git: Shell {

    /// Git aliases to make the API more convenient
    public enum Alias {
        case cmd(Command, String? = nil)
        case addAll
        case status(short: Bool = false)
        case commit(message: String, Bool = false)
        case config(name: String, value: String)
        case clone(url: String)

        /// - parameter branch the name of the branch to checkout
        /// - parameter create whether to create a new branch or checkout an existing one
        /// - parameter tracking when creating a new branch, the name of the remote branch it should track
        case checkout(branch: String, create: Bool = false, tracking: String? = nil)

        case log(numberOfCommits: Int? = nil, options: [String]? = nil, revisions: String? = nil)
        case push(remote: String? = nil, branch: String? = nil)
        case pull(remote: String? = nil, branch: String? = nil, rebase: Bool = false)
        case merge(branch: String)
        case create(branch: String)
        case delete(branch: String)
        case tag(String)
        case fetch(remote: String? = nil, branch: String? = nil)
        case submoduleUpdate(init: Bool = false, recursive: Bool = false, rebase: Bool = false)
        case submoduleForeach(recursive: Bool = false, command: String)
        case renameRemote(oldName: String, newName: String)
        case addRemote(name: String, url: String)
        case revParse(abbrevRef: String)
        case revList(branch: String, count: Bool = false, revisions: String? = nil)
        case raw(String)
        case lsRemote(url: String, limitToHeads: Bool = false)

        private func commandParams() -> [String] {
            var params: [String] = []
            switch self {
            case .cmd(let command, let args):
                params = [command.rawValue]
                if let args = args {
                    params.append(args)
                }
            case .addAll:
                params = [Command.add.rawValue, "."]
            case .status(let short):
                params = [Command.status.rawValue]
                if short {
                    params.append("--short")
                }
            case .commit(let message, let allowEmpty):
                params = [Command.commit.rawValue, "-m", "\"\(message)\""]
                if allowEmpty {
                    params.append("--allow-empty")
                }
            case .clone(let url):
                params = [Command.clone.rawValue, url]
            case .checkout(let branch, let create, let tracking):
                params = [Command.checkout.rawValue]
                if create {
                    params.append("-b")
                }
                params.append(branch)
                if let tracking {
                    params.append(tracking)
                }
            case .log(let numberOfCommits, let options, let revisions):
                params = [Command.log.rawValue]
                if let numberOfCommits = numberOfCommits {
                    params.append("-\(numberOfCommits)")
                }
                if let options = options {
                    params.append(contentsOf: options)
                }
                params.append("--")
                if let revisions = revisions {
                    params.append(revisions)
                }
            case .push(let remote, let branch):
                params = [Command.push.rawValue]
                if let remote = remote {
                    params.append(remote)
                }
                if let branch = branch {
                    params.append(branch)
                }
            case .pull(let remote, let branch, let rebase):
                params = [Command.pull.rawValue]
                if rebase {
                    params.append("--rebase")
                }
                if let remote = remote {
                    params.append(remote)
                }
                if let branch = branch {
                    params.append(branch)
                }
            case .merge(let branch):
                params = [Command.merge.rawValue, branch]
            case .create(let branch):
                params = [Command.checkout.rawValue, "-b", branch]
            case .delete(let branch):
                params = [Command.branch.rawValue, "-D", branch]
            case .tag(let name):
                params = [Command.tag.rawValue, name]
            case .fetch(let remote, let branch):
                params = [Command.fetch.rawValue]
                if let remote = remote {
                    params.append(remote)
                }
                if let branch = branch {
                    params.append(branch)
                }
            case .submoduleUpdate(let initialize, let recursive, let rebase):
                params = [Command.submodule.rawValue, "update"]
                if initialize {
                    params.append("--init")
                }
                if recursive {
                    params.append("--recursive")
                }
                if rebase {
                    params.append("--rebase")
                }
            case .submoduleForeach(let recursive, let command):
                params = [Command.submodule.rawValue, "foreach"]
                if recursive {
                    params.append("--recursive")
                }
                params.append(command)
            case .renameRemote(let oldName, let newName):
                params = [Command.remote.rawValue, "rename", oldName, newName]
            case .addRemote(let name, let url):
                params = [Command.remote.rawValue, "add", name, url]
            case .raw(let command):
                params.append(command)
            case .config(name: let name, value: let value):
                params = [Command.config.rawValue, "--add", name, value]
            case .revParse(abbrevRef: let abbrevRef):
                params = [Command.revParse.rawValue, "--abbrev-ref", abbrevRef]
            case .revList(let branch, let count, let revisions):
                params = [Command.revList.rawValue]
                if count {
                    params.append("--count")
                }
                if let revisions = revisions {
                    params.append(revisions)
                }
            case .lsRemote(url: let url, limitToHeads: let limitToHeads):
                params = [Command.lsRemote.rawValue]
                if limitToHeads {
                    params.append("--heads")
                }
                params.append(url)
            }
            return params
        }
        
        public var rawValue: String {
            self.commandParams().joined(separator: " ")
        }
    }

    /// basic git commands
    public enum Command: String {

        // MARK: - start a working area (see also: git help tutorial)

        case config

        case clean
        /// Clone a repository into a new directory
        case clone
        /// Create an empty Git repository or reinitialize an existing one
        case initialize = "init"

        // MARK: - work on the current change (see also: git help everyday)

        /// Add file contents to the index
        case add
        /// Move or rename a file, a directory, or a symlink
        case mv
        /// Reset current HEAD to the specified state
        case reset
        /// Remove files from the working tree and from the index
        case rm
        
        // MARK: - examine the history and state (see also: git help revisions)

        /// Use binary search to find the commit that introduced a bug
        case bisect
        /// Print lines matching a pattern
        case grep
        /// Show commit logs
        case log
        /// Show various types of objects
        case show
        /// Show the working tree status
        case status

        // MARK: - grow, mark and tweak your common history

        /// List, create, or delete branches
        case branch
        /// Switch branches or restore working tree files
        case checkout
        /// Record changes to the repository
        case commit
        /// Show changes between commits, commit and working tree, etc
        case diff
        /// Join two or more development histories together
        case merge
        /// Reapply commits on top of another base tip
        case rebase
        /// Create, list, delete or verify a tag object signed with GPG
        case tag

        // MARK: - collaborate (see also: git help workflows)

        /// Download objects and refs from another repository
        case fetch
        /// Fetch from and integrate with another repository or a local branch
        case pull
        /// Update remote refs along with associated objects
        case push
        /// Manage submodules
        case submodule
        /// Manage git remotes
        case remote
        /// Get information about specific revisions
        case revParse = "rev-parse"
        /// Lists commit objects in reverse chronological order
        case revList = "rev-list"
        /// List references in a remote repository
        case lsRemote = "ls-remote"
    }
    
    // MARK: - private helper methods
    
    /**
        This method helps to assemble a Git command string from an alias
     
        If there is a git repo path (working directory) presented, proper directories
        will be used & created recursively if a new repository is being initialized.
     
        - Parameters:
            - alias: The git alias to be executed
            - args: Additional arguments for the Git alias
     
        - Returns: The Git command
     */
    private func rawCommand(_ alias: Alias) -> String {
        var cmd: [String] = []
        // if there is a path let's change directory first
        if let path = self.path {
            // try to create work dir at given path for init or clone commands
            if
                alias.rawValue.hasPrefix(Command.initialize.rawValue) ||
                alias.rawValue.hasPrefix(Command.clone.rawValue)
            {
                cmd += ["mkdir", "-p", path, "&&"]
            }
            cmd += ["cd", path, "&&"]
        }
        cmd += ["git", alias.rawValue]
        
        let command = cmd.joined(separator: " ")

        if self.verbose {
            print(command)
        }
        return command
    }
    
    // MARK: - public api

    /// work directory, if peresent a directory change will occur before running any Git commands
    ///
    /// NOTE: if the git init command is called with a non-existing path, directories
    /// presented in the path string will be created recursively
    public var path: String?
    
    // prints git commands constructed from the alias before execution
    public var verbose = false
    
    /**
        Initializes a new Git object
     
        - Parameters:
            - path: The path of the Swift package (work directory)
            - type: The type of the shell, default: /bin/sh
            - env: Additional environment variables for the shell, default: empty
     
     */
    public init(path: String? = nil, type: String = "/bin/sh", env: [String: String] = [:]) {
        self.path = path

        super.init(type, env: env)
    }

    /**
        Runs a specific Git alias through the current shell.
     
        - Parameters:
            - alias: The git command alias to be executed

        - Throws:
            `ShellError.outputData` if the command execution succeeded but the output is empty,
            otherwise `ShellError.generic(Int, String)` where the first parameter is the exit code,
            the second is the error message
     
        - Returns: The output string of the command without trailing newlines
     */
    @discardableResult
    public func run(_ alias: Alias) throws -> String {
        try self.run(self.rawCommand(alias))
    }

    /**
        Async version of the run function
     
        - Parameters:
            - alias: The git command alias to be executed
            - completion: The completion block with the output and error

        The command will be executed on a concurrent dispatch queue.
     */
    public func run(_ alias: Alias, completion: @escaping ((String?, Swift.Error?) -> Void)) {
        self.run(self.rawCommand(alias), completion: completion)
    }
}
