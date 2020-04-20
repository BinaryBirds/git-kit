# GitKit (🐱)

GitKit is a Swift wrapper around the git command line interface.

## Usage

Some basic examples:

```swift
import GitKit

try Git().run(.cmd(.config, "--global user.name"))

let git = Git(path: "~/example/")

try git.run(.cmd(.initialize))
try git.run(.cmd(.status))
try git.run(.cmd(.branch, "-a"))
try git.run(.cmd(.pull))

try git.run(.clone(url: "https://gitlab.com/binarybirds/shell-kit.git"))
try git.run(.commit(message: "some nasty bug fixed"))
try git.run(.log(1))
try git.run(.tag("1.0.0"))
try git.run(.pull(remote: "origin", branch: "master"))
try git.run(.push(remote: "origin", branch: "master"))
try git.run(.create(branch: "dev"))
try git.run(.checkout(branch: "master"))
try git.run(.merge(branch: "dev"))

try git.run(.raw("log -2"))
try git.run(.raw("rebase -i <hash>"))

```

## Install

Just use the Swift Package Manager as usual:

```swift
.package(url: "https://github.com/binarybirds/git-kit", from: "1.0.0"),
```

Don't forget to add "GitKit" to your target as a dependency:

```swift
.product(name: "GitKit", package: "git-kit"),
```

That's it.


## License

[WTFPL](LICENSE) - Do what the fuck you want to.
