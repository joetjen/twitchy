defmodule Twitchy.MixProject do
  use Mix.Project

  def project do
    [
      app: :twitchy,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "test.unit": :test,
        "test.integration": :test,
        "test.all": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Twitchy.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # HTTP client and JSON
      {:req, "~> 0.5"},
      {:finch, "~> 0.18"},
      {:mint_web_socket, "~> 1.0"},
      {:jason, "~> 1.4"},

      # Configuration and utilities
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.2"},

      # Dev and test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp description do
    """
    A comprehensive Elixir client for the Twitch Helix API with EventSub support,
    featuring OAuth authentication, rate limiting, telemetry, and pipeline-friendly design.
    """
  end

  defp package do
    [
      name: "twitchy",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/joetjen/twitchy"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "QUICKSTART.md",
        "USAGE_GUIDE.md",
        "EXAMPLES.md",
        "CHANGELOG.md",
        "docs/api/USERS_STREAMS.md",
        "docs/api/CHANNELS_GAMES.md",
        "docs/api/VIDEOS_CLIPS.md",
        "docs/api/CHAT_MODERATION.md",
        "docs/api/SUBSCRIPTIONS_CHANNELPOINTS.md",
        "docs/api/PREDICTIONS_POLLS_HYPETRAIN.md",
        "docs/api/BITS_TEAMS_SCHEDULE_RAIDS.md",
        "docs/api/ANALYTICS_SEARCH_ADS_MISC.md"
      ],
      groups_for_extras: [
        Guides: ~r/^(README|QUICKSTART|USAGE_GUIDE|EXAMPLES|CHANGELOG)/,
        "API Documentation": ~r/^docs\/api/
      ]
    ]
  end

  defp aliases do
    [
      "test.unit": ["test --exclude integration"],
      "test.integration": ["test --only integration"],
      "test.all": ["test --include integration"],
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "test"
      ]
    ]
  end
end
