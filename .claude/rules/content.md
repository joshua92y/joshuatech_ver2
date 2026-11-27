---
paths:
  - "content/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/content_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `content/`

`content/study/*.mdx` are learning-in-public notes consumed by the site (SP-1 onward). Contract:

```yaml
---
title: "..."                        # required; Korean allowed
description: "..."                  # required; one sentence
pubDate: 2026-08-26                 # required; ISO date
updatedDate: 2026-08-27             # optional
tags: ["claude-code", "spec-kit"]   # required; may be empty
series: "sp-0-claude-setup"         # optional
seriesOrder: 1                      # optional positive integer
draft: true                         # required; generated notes start true, a human flips it to false
change: "001-claude-setup"          # required; the feature directory name
sources:                            # required; may be empty; each item has exactly one of path (repo-relative: ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$, no . or .. segment) or url (http/https)
  - { title: "spec", path: "specs/001-claude-setup/spec.md" }
---
```

- File name = `<NNN-slug>.mdx` (ASCII kebab-case). One note per feature; a second note for the same feature gets a `-2` suffix only after asking the human. A translation sits next to it as `<NNN-slug>.en.mdx` or `<NNN-slug>.ja.mdx`, with the same `pubDate` and `change` as the Korean file, which must exist (the loader fails otherwise — T090).
- `content/blog/` and `content/projects/` use the same front matter with `change` optional; a translation follows the same rules (same `pubDate`, Korean file required) and carries the same `change` as its Korean file, or neither has one; file names are ASCII kebab-case slugs (`^[a-z0-9]+(-[a-z0-9]+)*(\.(en|ja))?\.mdx$`) — provisional until SP-2 (T090).
- Body sections, in this order: `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`. Each must be non-empty.
- Bodies are Markdown + GFM even though the file is `.mdx`: no JSX or HTML tags (`<…>`, comments included), no `import`/`export` lines, no `{` or `}` outside code spans and fenced code, and link, image and definition URLs only `http`, `https`, `mailto` (scheme in any case), relative paths or `#` fragments. Front matter is YAML between exact `---` lines starting at the first line of the file (no BOM, no `---js` or other languages). The loader parses notes as plain Markdown and fails the build on any violation (file, line, rule — never the offending value) — it never strips one silently.
- Front matter is read as YAML 1.2 (core schema): dates stay `YYYY-MM-DD` strings; lines may end in LF, CRLF or CR; every key, quoted or not, matches `^[A-Za-z][A-Za-z0-9_]{0,63}$`; directives (`%…`), extra document markers (`---`, `...`) inside the block, anchors and aliases, YAML warnings such as unknown tags (YAML 1.1 tags such as `!!timestamp` or `!!set` included), and a block that is not a mapping are front matter errors. String values (`title`, `description`, `series`, each tag, each source `title`) are never empty or whitespace only. A front matter error names the file, the field path and the rule (an unknown key is named by the key itself), never a value. In front matter and body, an `http`/`https` URL never carries user info (`user:token@host`), and no URL contains whitespace, a control character or `\`; a front matter `sources[].url` host must be shaped like a domain name (dot-separated labels ending in an ASCII-letter top-level label), so localhost, IP addresses in any notation, single-label hosts, a trailing dot and `xn--` top-level labels are rejected. This is a shape check only: internal names such as `*.local`, `*.internal`, `*.home.arpa` or `*.localhost` pass, so keep them out by hand. The loader reads every entry whose name ends in `.mdx` in any letter case: a name outside the file-name rule (another case such as `.MDX`, a leading `.`, a non-ASCII character) and an entry that is not a regular file (a directory, symbolic link or junction) fail the build; other extensions are ignored. Code fences are highlighted at build time for a fixed language list; other languages render as plain text (T090).
- Write for a reader who was not in the session: state the concept, why it mattered here, what was rejected and why.
- Never include secrets, tokens, internal hostnames, or personal data.

## `content/tmp/` — learning-log staging (never published)

`content/tmp/<NNN>-t<NNN>/<YYYY-MM-DD>.md` holds per-task learning logs that `/finish` later distills into the feature's note. The site never loads `content/tmp/**`.

- One directory per task (`003-t044` = feature 003, task T044; lowercase ASCII). One file per working day, so a multi-day task gets several files. Plain Markdown, no frontmatter; the first line is `# <NNN-slug> T<NNN> — <one-line title> (<YYYY-MM-DD>)`.
- The controller appends the day's entry when it ticks the task checkbox, and at the end of each session of a multi-day task. Entry sections mirror the note, in this order: `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`, then `## 사고·오류` (only when something went wrong) and `## 출처` (commit hashes, PR numbers, runbook anchors, `specs/<feature>/design/` files).
- Same publication bar as notes: never include secrets, tokens, internal hostnames or IP addresses, resource identifiers, or personal data. This repository is public — write every entry as if it were already published.
- Lifecycle: `/finish` reads `content/tmp/<NNN>-*/` as a source of substance. After the finish review's Study contract boundary is ✅, the consumed directories are deleted in the same commit as the note; git history keeps them. An empty `content/tmp/` means everything has been distilled.
