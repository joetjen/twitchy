# Twitchy Examples

Runnable example applications demonstrating real-world use cases for the Twitchy library.

## Prerequisites

Before running any examples, you need:

1. **Twitch Developer Account**
   - Register at <https://dev.twitch.tv/console>
   - Create an application to get Client ID and Client Secret

2. **Environment Setup**

   ```bash
   export TWITCH_CLIENT_ID="your_client_id"
   export TWITCH_CLIENT_SECRET="your_client_secret"
   export TWITCH_REDIRECT_URI="http://localhost:4000/auth/callback"  # For OAuth examples
   ```

3. **Install Dependencies**

   ```bash
   cd /path/to/twitchy
   mix deps.get
   ```

## Examples

### 1. Stream Monitor (`stream_monitor.exs`)

Monitors multiple Twitch streamers and prints when they go live or offline.

**Features:**

- Real-time monitoring using EventSub WebSocket
- Tracks stream title, game, and viewer count changes
- Gracefully handles connection issues

**Run:**

```bash
elixir examples/stream_monitor.exs
```

**Customize:**
Edit the `@streamers` list in the file with broadcaster user IDs you want to monitor.

### 2. Clip Downloader (`clip_downloader.exs`)

Downloads top clips from a broadcaster within a specified time period.

**Features:**

- Fetches clips by view count
- Downloads video files
- Organizes clips by broadcaster

**Run:**

```bash
# Download top 10 clips from the last 7 days
elixir examples/clip_downloader.exs --broadcaster ninja --days 7 --count 10
```

### 3. Chat Logger (`chat_logger.exs`)

Logs chat messages from a Twitch channel to a file.

**Features:**

- Real-time chat message logging
- Includes timestamps, usernames, and badges
- Tracks chat statistics

**Run:**

```bash
elixir examples/chat_logger.exs --channel shroud
```

**Note:** Requires user authentication with `chat:read` scope.

### 4. Live Notification Bot (`live_notifier.exs`)

Sends notifications when followed streamers go live (can integrate with Discord, Slack, etc.).

**Features:**

- Monitors multiple streamers
- Sends desktop notifications (macOS, Linux)
- Template for Discord/Slack webhooks

**Run:**

```bash
elixir examples/live_notifier.exs
```

### 5. Analytics Dashboard (`analytics_collector.exs`)

Collects and stores stream analytics data over time.

**Features:**

- Periodic data collection (viewers, followers, subs)
- Exports to CSV
- Tracks growth metrics

**Run:**

```bash
# Collect data every 5 minutes
elixir examples/analytics_collector.exs --broadcaster ninja --interval 300
```

## Common Patterns

All examples follow these patterns:

1. **Configuration**: Load credentials from environment variables
2. **Error Handling**: Graceful error handling and logging
3. **Rate Limiting**: Respect Twitch API rate limits
4. **Telemetry**: Optional telemetry integration
5. **Signal Handling**: Clean shutdown on SIGINT/SIGTERM

## Development

To modify or extend examples:

1. Copy an example file
2. Modify the configuration or logic
3. Run with `elixir your_example.exs`

## Troubleshooting

### Authentication Errors

- Verify Client ID and Client Secret are correct
- Check that credentials are exported in current shell
- For OAuth flows, ensure Redirect URI matches your app settings

### EventSub Connection Issues

- Check your internet connection
- Verify broadcaster IDs are correct
- EventSub requires App Access or User Access token

### Rate Limiting

- The library automatically handles rate limits
- For high-volume applications, consider caching responses
- Monitor telemetry events to track API usage

## Further Reading

- [Quick Start Guide](../QUICKSTART.md)
- [Usage Guide](../USAGE_GUIDE.md)
- [API Documentation](../docs/api/)
- [Twitch API Documentation](https://dev.twitch.tv/docs/api/)

## Support

For issues or questions:

- Check the [main documentation](../README.md)
- Open an issue on GitHub
- Join the Twitch Developers Discord
