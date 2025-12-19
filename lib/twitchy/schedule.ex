defmodule Twitchy.Schedule do
  @moduledoc """
  Twitch Schedule API endpoints.

  Provides functions for managing and retrieving stream schedules.

  ## Examples

      # Get stream schedule
      {:ok, response} = Twitchy.Schedule.get_channel_stream_schedule(client,
        broadcaster_id: "12345"
      )

      # Create schedule segment
      {:ok, response} = Twitchy.Schedule.create_channel_stream_schedule_segment(client,
        broadcaster_id: "12345",
        start_time: "2024-01-01T12:00:00Z",
        timezone: "America/New_York",
        duration: "60",
        title: "Stream Title"
      )
  """

  alias Twitchy.HTTP

  @doc """
  Gets the broadcaster's stream schedule.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Filter by segment ID(s) (max 100)
  - `:start_time` - Start time (RFC3339)
  - `:utc_offset` - UTC offset in minutes
  - `:first` - Number of results per page (max 25, default 20)
  - `:after` - Cursor for pagination

  ## Examples

      {:ok, response} = Twitchy.Schedule.get_channel_stream_schedule(client,
        broadcaster_id: "12345",
        first: 25
      )
  """
  @spec get_channel_stream_schedule(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def get_channel_stream_schedule(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/schedule", query: query)
  end

  @doc """
  Gets the broadcaster's iCalendar.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)

  ## Examples

      {:ok, icalendar} = Twitchy.Schedule.get_channel_icalendar(client, broadcaster_id: "12345")
  """
  @spec get_channel_icalendar(Twitchy.t(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def get_channel_icalendar(client, params) do
    query = HTTP.build_query(params)
    HTTP.get(client, "/schedule/icalendar", query: query)
  end

  @doc """
  Updates the broadcaster's stream schedule settings.

  Requires the `channel:manage:schedule` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:is_vacation_enabled` - Enable vacation mode
  - `:vacation_start_time` - Vacation start time (RFC3339)
  - `:vacation_end_time` - Vacation end time (RFC3339)
  - `:timezone` - Timezone (IANA format)

  ## Examples

      {:ok, _} = Twitchy.Schedule.update_channel_stream_schedule(client,
        broadcaster_id: "12345",
        is_vacation_enabled: true,
        vacation_start_time: "2024-07-01T00:00:00Z",
        vacation_end_time: "2024-07-14T23:59:59Z"
      )
  """
  @spec update_channel_stream_schedule(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_channel_stream_schedule(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    query = [broadcaster_id: broadcaster_id]
    body = Map.new(params)

    HTTP.patch(client, "/schedule/settings", query: query, json: body)
  end

  @doc """
  Creates a stream schedule segment.

  Requires the `channel:manage:schedule` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:start_time` - Start time (RFC3339, required)
  - `:timezone` - Timezone (IANA format, required)
  - `:duration` - Duration in minutes (required, max 1440)
  - `:is_recurring` - Is recurring segment
  - `:category_id` - Game/category ID
  - `:title` - Segment title (max 140 characters)

  ## Examples

      {:ok, response} = Twitchy.Schedule.create_channel_stream_schedule_segment(client,
        broadcaster_id: "12345",
        start_time: "2024-01-15T20:00:00Z",
        timezone: "America/New_York",
        duration: "120",
        category_id: "21779",
        title: "League of Legends Ranked"
      )
  """
  @spec create_channel_stream_schedule_segment(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def create_channel_stream_schedule_segment(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    query = [broadcaster_id: broadcaster_id]
    body = Map.new(params)

    HTTP.post(client, "/schedule/segment", query: query, json: body)
  end

  @doc """
  Updates a stream schedule segment.

  Requires the `channel:manage:schedule` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Segment ID (required)
  - Plus any fields from create_channel_stream_schedule_segment/2

  ## Examples

      {:ok, response} = Twitchy.Schedule.update_channel_stream_schedule_segment(client,
        broadcaster_id: "12345",
        id: "segment-id",
        title: "Updated Title",
        duration: "90"
      )
  """
  @spec update_channel_stream_schedule_segment(Twitchy.t(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def update_channel_stream_schedule_segment(client, params) do
    {broadcaster_id, params} = Keyword.pop!(params, :broadcaster_id)
    {segment_id, params} = Keyword.pop!(params, :id)

    query = [broadcaster_id: broadcaster_id, id: segment_id]
    body = Map.new(params)

    HTTP.patch(client, "/schedule/segment", query: query, json: body)
  end

  @doc """
  Deletes a stream schedule segment.

  Requires the `channel:manage:schedule` scope.

  ## Parameters

  - `:broadcaster_id` - Broadcaster's user ID (required)
  - `:id` - Segment ID (required)

  ## Examples

      :ok = Twitchy.Schedule.delete_channel_stream_schedule_segment(client,
        broadcaster_id: "12345",
        id: "segment-id"
      )
  """
  @spec delete_channel_stream_schedule_segment(Twitchy.t(), keyword()) :: :ok | {:error, Exception.t()}
  def delete_channel_stream_schedule_segment(client, params) do
    query = HTTP.build_query(params)

    case HTTP.delete(client, "/schedule/segment", query: query) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
