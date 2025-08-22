# codeview.nvim

A Neovim plugin for offline-first code review, offering two complementary views
for exploring git diffs.

## Why codeview.nvim?

Web-based reviews force you to switch between editor and browser, breaking
focus and leaving behind your local tools like formatters, linters, and LSP.
They also tie reviews to pull requests, so you can’t as easily review arbitrary
commits or unstaged changes without pushing to a remote.

`codeview.nvim` removes these barriers. You can review any changes (committed,
staged, or not yet pushed) directly inside Neovim, with full access to your
tools and the ability to make inline edits.

Review comments can live in the code itself, preserving context. What you do
with them is up to you: turn them into a separate review commit, squash them
out later, only leave them locally etc.

## Working with AI Coding Agents

I was motivated to make this tool after playing around with AI coding agents
(like Claude Code).

AI-generated code often needs careful review before committing. With
`codeview.nvim`, you can inspect changes locally before they leave your
machine, leave inline comments for the AI to address, and review incrementally
as code is produced. Because reviews happen in the same environment where the
code runs, testing and validation are immediate and reliable.

Of course, this tool does does not stipulate usage with any AI tools. It's
still useful by itself.

## Usage

`codeview.nvim` provides two views for analyzing git diffs. Both automatically
refresh when you re-enter the buffer, so any file changes you make will be
visible when you return.

### Table View (`:CodeViewTable`)

- Presents a compact overview of all changed files, with additions and
  deletions shown per file.
- Press `<CR>` on a file to open it in diff view.
- Press `<S-CR>` (Shift + Enter) to open an isolated diff for that file only.

| Command                        | Description                                                    |
| ------------------------------ | -------------------------------------------------------------- |
| `:CodeViewTable`               | Show unstaged changes (`git diff`)                             |
| `:CodeViewTable --staged`      | Show staged changes (`git diff --staged`)                      |
| `:CodeViewTable <ref>`         | Compare working tree against a reference (branch, commit, tag) |
| `:CodeViewTable <ref1> <ref2>` | Compare two references                                         |

### Diff View (`:CodeViewDiff`)

- Displays a unified diff with file navigation capabilities.
- Press `<CR>` on any line to jump directly to the corresponding location in
  the file.

| Command                       | Description                                                    |
| ----------------------------- | -------------------------------------------------------------- |
| `:CodeViewDiff`               | Show unstaged changes (`git diff`)                             |
| `:CodeViewDiff --staged`      | Show staged changes (`git diff --staged`)                      |
| `:CodeViewDiff <ref>`         | Compare working tree against a reference (branch, commit, tag) |
| `:CodeViewDiff <ref1> <ref2>` | Compare two references                                         |
