# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues.

Repository:

<https://github.com/200166shang/robot-docker>

Use the `gh` CLI for all issue operations.

## Conventions

- Create an issue with `gh issue create --title "..." --body "..."`
- Read an issue with `gh issue view <number> --comments`
- List issues with `gh issue list`
- Comment with `gh issue comment <number> --body "..."`
- Apply labels with `gh issue edit <number> --add-label "..."`
- Remove labels with `gh issue edit <number> --remove-label "..."`
- Close with `gh issue close <number> --comment "..."`

Infer the repository from `git remote -v` when operating inside a clone.

## Pull requests as a triage surface

PRs are not treated as a triage request surface.

## When a skill says “publish to the issue tracker”

Create a GitHub issue.

## When a skill says “fetch the relevant ticket”

Run `gh issue view <number> --comments`.
