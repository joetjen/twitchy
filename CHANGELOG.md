# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Generated documentation is now published to GitHub Pages (`https://joetjen.github.io/twitchy`) on every push to `main` via the `docs.yml` workflow, and linked from `mix.exs` (`source_url`/`homepage_url`) and the README.
- `plug` as an optional dependency, so `Twitchy.EventSub.Webhook` compiles without warnings for consumers who don't use it.

### Fixed

- README license notice, which still said MIT after the project switched to Apache-2.0.
- `Twitchy.authenticate/3` no longer declares a default argument on more than one clause head.
- `Twitchy.TokenStore.Memory` no longer defines `init/1` twice (once for `GenServer`, once for `Twitchy.Behaviours.TokenStore`); the pure state-handling logic moved to the internal `Twitchy.TokenStore.Memory.State` module.
