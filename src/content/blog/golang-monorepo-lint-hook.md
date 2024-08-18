---
title: 'Golang Monorepo: Linting individual Go Modules using Lefthook'
description: 'Set up linting for individual Go modules in a Golang monorepository using Git hooks with Lefthook.'
pubDate: 'Aug 18 2024'
heroImage: '/golang-monorepo-lint-hook.png'
---

Managing a monorepository can be challenging, especially when it comes to maintaining code quality across multiple Go modules. One effective way to ensure consistent code quality is by using linting tools. In this blog post, we’ll explore how to set up linting for individual Go modules in a Golang monorepository using Git hooks with [Lefthook](https://github.com/evilmartians/lefthook).

Running the linters against a whole module instead of only the changed files has the advantage to catch more complex issues, such as cyclic dependencies, unused code, and issues that span multiple files.

## Example monorepo

Lets get started by setting up an example monorepo. This will initialize two Go modules with some sample code, initialize a Go workspace and a Git repo.
```sh
mkdir monorepo-example && \
  cd monorepo-example && \
  for i in 1 2; do mkdir service$i && (cd service$i && go mod init service$i && echo 'package main\n\nimport "fmt"\n\n//const unused = "unused"\n\nfunc main() {\n    fmt.Println("Hello from service'$i'")\n}' > main.go); done && \
  go work init $(for i in 1 2; do echo ./service$i; done) && \
  git init && git add . && git commit -m "Initial"
```

The project structure should look like:
```sh
./
├── go.work
├── service1
│   ├── go.mod
│   └── main.go
└── service2
    ├── go.mod
    └── main.go
```

## Install golangci-lint

[golangci-lint](https://golangci-lint.run) is a fast and flexible linter for Go, which aggregates multiple linters to analyze Go code for potential issues, such as bugs, stylistic errors, and performance problems.

To install `golangci-lint` using `go install`, run the following command:
```sh
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

Lets run the linter in one of the modules:
```sh
cd service1 && \
  golangci-lint run ./... && \
  cd ..
```

Without a configuration file the defaults will be used. There should be no linter errors so far.

## Set up Lefthook

Lefthook is a powerful and flexible Git hooks manager that allows us to run scripts and commands before or after certain Git events, such as commits or pushes. It is particularly useful for enforcing code quality standards and automating repetitive tasks.

### Installation

Run the following command to install Lefthook via `go install`:
```sh
go install github.com/evilmartians/lefthook@latest
```

### Configuration

Place a `lefthook.yml` file in the root directory of the repository. This file will specify the hooks, along with the commands and scripts that should be executed.

```yaml
pre-commit:
  scripts:
    "golangci-lint.sh":
      runner: sh
```

The configuration includes a single script, `golangci-lint.sh`, designated as a pre-commit script. This script will be executed automatically as a pre-commit hook, ensuring that the specified linting checks are performed before any commit is finalized.

### Reusable functions

Next, we’ll create a shell script named `monorepo-utils.sh` that includes some useful functions that can be reused in multiple hook scripts. The key function we’ll utilize from our hook script is `get_unique_go_mod_dirs`, which takes a list of file paths (.go files) and returns a list of unique directory paths for each of the changed Go modules.

Create the `.lefthook/scripts/monorepo-utils.sh` file and make it executable.

```sh
#!/bin/sh

# Function to determine the go.mod directory path for a given .go file
get_go_mod_dir() {
    local file=$1
    local dir=$(dirname "$file")
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/go.mod" ]; then
            echo "$dir"
            return
        fi
        dir=$(dirname "$dir")
    done
}

# Function to create a unique array of go.mod directories
get_unique_go_mod_dirs() {
    local files=("$@")
    local go_mod_dirs=()
    for file in $files; do
        go_mod_path=$(get_go_mod_dir "$file")
        if [ -n "$go_mod_path" ]; then
            if [[ ! " ${go_mod_dirs[@]} " =~ " ${go_mod_path} " ]]; then
                go_mod_dirs+=("$go_mod_path")
            fi
        fi
    done
    echo "${go_mod_dirs[@]}"
}
```

### Pre-commit hook script

Create the `.lefthook/pre-commit/golangci-lint.sh` file and make it executable.

```sh
#!/bin/sh

# Load utility scripts
scripts_dir=$(dirname "$(realpath "$0")")/../scripts
source $scripts_dir/monorepo-utils.sh

# Get a list of staged .go files
staged_files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.go$')

# Get a list of changed modules
go_modules=$(get_unique_go_mod_dirs "${staged_files[@]}")

# Loop all module directories and run linters
for path in $go_modules; do
    (
        cd $path || exit
        echo "Execution path: $(pwd)"
        golangci-lint run ./...
    )
done
```

First, the script loads the utility functions. Then, it creates a list of staged `.go` files, passes them to the `get_unique_go_mod_dirs` function to get the list of modules that have been changed.

To wrap things up, add the Lefthook files to Git:
```sh
git add . && git commit -m "Lefthook configuration"
```

Our project should now look like:
```sh
./
├── .lefthook
│   ├── pre-commit
│   │   └── golangci-lint.sh
│   └── scripts
│       └── monorepo-utils.sh
├── go.work
├── lefthook.yml
├── service1
│   ├── go.mod
│   └── main.go
└── service2
    ├── go.mod
    └── main.go
```

### Install the hook into Git

Run the following command:
```sh
lefthook install
```

This will instruct Lefthook to place the hook into `.git/hooks/pre-commit` and activate it.

## Update some code and test the hook

Finally, lets test our setup by uncommenting the `const unused = "unused"` line in `main.go` in one of the modules (e.g. service1).

Stage the file and try to commit:
```sh
git add . && git commit -m "Test"
╭───────────────────────────────────────╮
│ 🥊 lefthook v1.7.14  hook: pre-commit │
╰───────────────────────────────────────╯
┃  golangci-lint.sh ❯

Execution path: /Users/cm51sn/Developer/workspace/public/thmshmm/monorepo-example/service1
main.go:5:7: const `unused` is unused (unused)
const unused = "unused"
      ^

  ────────────────────────────────────
summary: (done in 0.83 seconds)
🥊  golangci-lint.sh
```

Thats it! `golangci-lint` was only executed in the `service1` module.

## Conclusion

In conclusion, while not all tools are equipped to handle monorepositories out of the box, we’ve demonstrated how Lefthook can be used to effectively manage git hooks for individual modules within a Golang monorepo.

The principles and techniques showcased in this example can be easily extended to other areas such as testing, code formatting, and more. By leveraging these tools, you can create a robust and scalable workflow that enhances the overall quality and maintainability of your codebase. Happy coding! 🚀
