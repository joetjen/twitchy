# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Generated documentation is now published to GitHub Pages (`https://joetjen.github.io/twitchy`) on every push to `main` via the `docs.yml` workflow, and linked from `mix.exs` (`source_url`/`homepage_url`) and the README.
- `plug` as an optional dependency, so `Twitchy.EventSub.Webhook` compiles without warnings for consumers who don't use it.
- `docs/api/API_REFERENCE.md` as an index page linking every per-module API guide, so `mix docs` has a real target for "see all API modules" links.
- `Twitchy.Config.auth_base_url` (default `"https://id.twitch.tv/oauth2"`) so OAuth requests can be pointed at a different host than the Helix API base URL — e.g. a mock server in tests.
- Test coverage for `Twitchy.Pagination.stream/2` and `fetch_all/2`, which previously had none.
- `TUTORIAL.md`, a step-by-step walkthrough building a complete, real-world stream alert & moderation bot (auth, Users/Streams/Channel Points/Chat/Moderation, and EventSub WebSocket via `Twitchy.EventSub.Declarative`), ending in one full runnable module.
- A `## Tutorial` section in each `docs/api/*.md` guide, each building a small real-world tool for that API area (e.g. a "Who's Live" tracker for Users & Streams, a chat moderation assistant for Chat & Moderation, a subscriber/rewards dashboard for Subscriptions & Channel Points) and ending in a complete runnable example.

### Changed

- Project license switched from Apache-2.0 back to MIT.

### Fixed

- README license notice, which still said MIT after the project switched to Apache-2.0.
- `Twitchy.authenticate/3` no longer declares a default argument on more than one clause head.
- `Twitchy.TokenStore.Memory` no longer defines `init/1` twice (once for `GenServer`, once for `Twitchy.Behaviours.TokenStore`); the pure state-handling logic moved to the internal `Twitchy.TokenStore.Memory.State` module.
- `mix docs` no longer emits warnings: `EVENTSUB_EXAMPLES.md`, `TESTING_GUIDE.md`, and `LICENSE` are now registered as `ex_doc` extras, broken/typo'd cross-links in `docs/api/*.md` (`CHANNELS.md`, `PREDICTIONS_POLLS.md`, wrong-depth `EVENTSUB_EXAMPLES.md` references) point at the correct files, and a missing closing code fence in `TESTING_GUIDE.md` that was corrupting the rest of the document's Markdown parsing has been closed.
- `Twitchy.Pagination.stream/2` no longer halts before fetching a single page when called with the default `nil` initial cursor. Every `stream_*` helper in the library (`Users.stream_followers/2`, `Games.stream_top_games/1`, etc.) went through this function, so streaming pagination previously always returned an empty stream.
- `Twitchy.Auth` no longer hardcodes `https://id.twitch.tv/oauth2` for every OAuth request; it now builds URLs from the new `config.auth_base_url`. Previously the module ignored client configuration entirely and always contacted the real Twitch endpoint, which also made it untestable.
- `Twitchy.TokenStore.Memory` (the default token store) is now started under `Twitchy.Application`'s supervision tree. Previously it was never started automatically, so any call that persisted a token (`get_app_access_token/1`, `exchange_code/2`, `refresh_token/1`) crashed with `:noproc` unless a consuming application happened to start the store itself.
- `Twitchy.HTTP.build_query/1` now expands list values (e.g. `id: ["1", "2"]`) into repeated `key=value` query pairs instead of handing a raw list to `Req`, which raised `ArgumentError`.
- `Twitchy.HTTP` no longer crashes extracting telemetry metadata from non-map response bodies (e.g. an empty `204 No Content` body).
- `Twitchy.Error.normalize/1` no longer crashes when a 4xx/5xx response body isn't a JSON map (e.g. a raw error string or an empty body from a non-JSON error response).
- `Twitchy.Error.AuthError` and `Twitchy.Error.RateLimitError` now honor their own `:message` field in `Exception.message/1` instead of ignoring it.
- `Twitchy.Users.get_user/2` now returns `{:error, :user_not_found}` instead of `{:ok, nil}` when no user matches, matching its documented behavior.
- `mix precommit` now runs under `MIX_ENV=test` automatically (`preferred_cli_env`) instead of failing when invoked from the default `:dev` environment.
- Various `credo --strict` findings across the codebase (unnecessary `with`, explicit `try`, excess function nesting/complexity, `length/1` vs `Enum.empty?/1`, unformatted numeric literals, a stale TODO with no corresponding test coverage).
- Several broken/fabricated code examples surfaced while writing the new tutorials, spread across the README, QUICKSTART, and `docs/api/*.md` guides: EventSub handler snippets that didn't match the real `{module, function, args}`/single-argument message shape (and were missing the required `:name`/`:version` options), calls to functions that don't exist in the library (e.g. non-existent `Users`/`Chat`/`Moderation`/`Teams` helpers that were never part of the public API), calls that passed a keyword list where a positional argument was required (`Twitchy.Users.block_user/3`, `unblock_user/2`), calls matching `{:ok, _}` against functions that actually return a bare `:ok` (several `Moderation`/`ChannelPoints`/`Raids`/`Schedule`/`Videos` functions), a missing required parameter on `Twitchy.Ads.snooze_next_ad/2`, and invalid Ruby-style `return ... if ...` syntax in a moderation bot example.
