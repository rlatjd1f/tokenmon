# Contributing

Thanks for looking at Tokenmon.

This repository is the canonical public, source-available codebase for
Tokenmon. External issues and pull requests should target this repository.

## What To Expect

- GitHub Releases, Sparkle app updates, and Homebrew installs are published
  from this repository.
- Issues are enabled for focused public bug reports, CLI discovery reports,
  provider proposals, and docs requests. Pick the closest issue template.
- Pull requests are welcome when they are focused, reproducible, and limited to
  public product/runtime changes.
- New provider integrations need an accepted provider proposal before merge
  review. See
  [docs/development/provider-proposals.md](docs/development/provider-proposals.md).
- Maintainer-only workflow assets, internal planning docs, original art review
  files, and private operator materials are not accepted in this repo.
- Release publishing stays here, so changes that affect the shipped app must
  keep public build and release checks working.

## Build And Verify

```bash
swift build
./scripts/ai-verify --mode pr
./scripts/build-release
```

## Public Repo Rules

- Keep the repo buildable from source.
- Do not include prompt text, model response text, API keys, or private
  machine-local secrets in issues, PRs, fixtures, or docs.
- Do not add maintainer-only workflow assets, internal review artifacts, or
  private operator docs here.
- Keep user-facing docs product-first and release-focused.
- If a public code change affects release behavior, update the relevant release
  scripts and public docs in the same change.

## License

Tokenmon is source-available under `FSL-1.1-ALv2`. See [LICENSE.md](LICENSE.md),
[LICENSE-assets.md](LICENSE-assets.md), and [TRADEMARKS.md](TRADEMARKS.md).
