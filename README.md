# git-upstream-update

A small, GitHub-specific helper that keeps your **fork's default branch in sync
with the upstream repository it was forked from** — in one command.

When you fork a project on GitHub and later want your fork's `main`/`master` to
match the original again, you normally have to: look up who you forked from, add
an `upstream` remote, fetch it, check out the default branch, fast-forward it,
and push it back to your fork. This script does all of that for you, and figures
out the upstream automatically by asking GitHub.

## Example

Run it from inside a clone of your fork:

```console
$ git-upstream-update.sh
>> querying GitHub for repository metadata...
>> upstream (parent) repo : gottcode/focuswriter
>> default branch         : main
>> adding remote 'upstream' -> https://github.com/gottcode/focuswriter.git
>> fetching from 'upstream'...
>> checking out 'main'...
>> fast-forwarding 'main' to 'upstream/main'...
>> done. 'main' is now up to date with gottcode/focuswriter.
>> pushing 'main' to origin...
>> pushed 'main' to origin.
```

That's the whole thing — it found the upstream, synced `main`, and pushed it
back to your fork. The rest of this README explains what happened and the
options available.

## How it works

Running `git-upstream-update.sh` inside a clone of your fork performs these
steps:

1. **Detect the fork.** It calls `gh repo view` to ask GitHub about the current
   repository. If GitHub doesn't consider it a fork, the script stops — there's
   no upstream to sync from.
2. **Find the upstream.** GitHub reports the `parent` repository a fork was
   created from (the same "forked from …" you see in the GitHub UI). That parent
   is treated as the upstream.
3. **Ensure the `upstream` remote.** If a git remote named `upstream` doesn't
   already exist, it's added automatically, pointing at
   `https://github.com/<parent-owner>/<parent-repo>.git`. If it already exists,
   it's left untouched.
4. **Determine the default branch.** It uses the upstream's default branch
   (falling back to your fork's), so `main`, `master`, or anything else is
   handled without configuration.
5. **Fetch and fast-forward.** It fetches the default branch from `upstream` and
   fast-forwards your local branch to it (`git merge --ff-only`), keeping your
   local branch a clean mirror of upstream. If your working tree has uncommitted
   changes, it refuses to run so nothing is clobbered.
6. **Push to your fork.** It pushes the freshly-updated branch to `origin`.

### Pushing is safe by default

The push to `origin` is **never forced by default**. If your fork's branch has
diverged from upstream (e.g. you committed directly to it), Git rejects the
non-fast-forward push and the script stops with:

```
warning: could not push to origin since it has diverged from upstream
         re-run with -f to force-push and overwrite the divergence
```

Your local branch is *already updated* at that point — only the push to `origin`
is skipped, so nothing on the remote is overwritten. If you genuinely want to
discard the divergent commits on your fork, re-run with `-f` (see below).

## Usage

Run it from inside a clone of your fork:

```sh
git-upstream-update.sh [-f] [--remote NAME]
```

| Option          | Description                                                                                          |
| --------------- | ---------------------------------------------------------------------------------------------------- |
| `-f`, `--force` | Force-push to `origin`, overwriting a diverged branch. Off by default; discards origin's divergence.  |
| `--remote NAME` | Name to use for the upstream remote (default: `upstream`).                                            |
| `-h`, `--help`  | Show usage.                                                                                           |

## Requirements

- [`git`](https://git-scm.com/)
- [`gh`](https://cli.github.com/) — the GitHub CLI, authenticated. Check with
  `gh auth status`.
- [`jq`](https://jqlang.github.io/jq/) — for parsing `gh`'s JSON output.

The script only works with repositories hosted on GitHub, since it relies on
`gh` to determine the fork relationship.

## Installation

`setup.sh` symlinks the script into `$HOME/bin` so you can run it from anywhere:

```sh
./setup.sh
```

Because it's a symlink, any edits to `git-upstream-update.sh` take effect
immediately — no need to re-install. If `$HOME/bin` isn't on your `PATH`, the
setup script tells you how to add it.

## Notes & limitations

- **GitHub only.** The fork/upstream detection depends on `gh`; it won't work for
  repos hosted elsewhere.
- **Default-branch fallback.** GitHub's `parent` payload doesn't always include
  the parent's default branch, so the script falls back to your fork's default
  branch. For the normal case (a fork keeps the same default branch as upstream)
  this is correct; a fork whose default branch differs from upstream's is the one
  edge case where it could pick the wrong branch.
- **Uncommitted changes block the sync.** Commit or stash first — this is
  intentional, to avoid losing work during the checkout/fast-forward.
