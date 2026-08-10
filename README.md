# GitKit (🐱)

GitKit is a Swift wrapper around the git command line interface.

## Usage

Every command is `async`. Some basic examples:

```swift
import GitKit

try await Git().run(.cmd(.config, "--global user.name"))

let git = Git(path: "~/example/")

try await git.run(.cmd(.initialize))
try await git.run(.cmd(.status))
try await git.run(.cmd(.branch, "-a"))
try await git.run(.cmd(.pull))

try await git.run(.clone(url: "https://github.com/armcknight/git-kit.git"))
try await git.run(.commit(message: "some nasty bug fixed"))
try await git.run(.log(numberOfCommits: 1))
try await git.run(.tag("1.0.0"))
try await git.run(.pull(remote: "origin", branch: "main"))
try await git.run(.push(remote: "origin", branch: "main"))
try await git.run(.create(branch: "dev"))
try await git.run(.checkout(branch: "main"))
try await git.run(.merge(branch: "dev"))

try await git.run(.raw("log -2"))
try await git.run(.raw("rebase -i <hash>"))
```

Commands are run through a shell (`/bin/sh` by default), so a raw command may
chain with `&&` exactly as it would at a prompt:

```swift
try await git.run("cd /some/path && git status")
```

Failures throw `Git.Error.generic(exitCode, stderr)`; output that cannot be
decoded throws `Git.Error.outputData`.

## Install

Just use the Swift Package Manager as usual:

```swift
.package(url: "https://github.com/armcknight/git-kit", from: "2.0.0"),
```

Don't forget to add "GitKit" to your target as a dependency:

```swift
.product(name: "GitKit", package: "git-kit"),
```

That's it.

## Migrating from 1.x

2.0.0 is a breaking release.

- **Async only.** `Git.run` is now `async throws`. The synchronous variant and
  the completion-handler variant (`run(_:completion:)`) are both gone. Call
  sites need `try await`.
- **No more ShellKit.** `Git` no longer subclasses `ShellKit.Shell`; commands
  run on [swift-subprocess](https://github.com/swiftlang/swift-subprocess).
  `binarybirds/shell-kit` was deleted from GitHub, so 1.x can no longer be
  resolved on a fresh checkout at all.
- **Errors moved.** `Shell.Error` is now `Git.Error`, with the same
  `outputData` and `generic(Int, String)` cases.
- **`Shell` members moved onto `Git`.** `path`, `verbose`, `type`, and `env`
  are unchanged; `maxOutputSize` is new (16MB default). The macOS-only
  `outputHandler` / `errorHandler` streaming hooks are gone.
- **Platform floor.** macOS 13, inherited from swift-subprocess.

The `Alias` and `Command` enums are unchanged, so command construction is
identical apart from the `await`.

## License

[WTFPL](LICENSE) - Do what the fuck you want to.
