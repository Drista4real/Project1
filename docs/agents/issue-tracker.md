# GitHub issue tracker

Repository: `Drista4real/Project1`. Store specifications and implementation
tickets in GitHub Issues. Run `gh` from this repository.

## Operations

- Create: `gh issue create --title "..." --body-file <path>`
- Read: `gh issue view <number> --json number,title,body,labels,comments`
- List: `gh issue list --state open --json number,title,body,labels`
- Comment: `gh issue comment <number> --body-file <path>`
- Label: `gh issue edit <number> --add-label "..." --remove-label "..."`
- Close: `gh issue close <number>`

Use UTF-8 files for multiline bodies. Publishing a spec or ticket means
creating an issue; fetching a ticket means reading that issue.

## Relationships and wayfinding

Represent parent/child relationships and blockers using native GitHub
links when supported. API calls require numeric database IDs, obtained
with `gh api repos/Drista4real/Project1/issues/<number> --jq .id`.

When native links are unavailable, write `Part of #<parent>` and
`Blocked by: #<number>` in ticket bodies, and list children in the parent.
Work only on unassigned tickets whose blockers are closed. Assign a
ticket to yourself before implementation; record the result before closing.

## Pull requests

PRs as a request surface: no.
