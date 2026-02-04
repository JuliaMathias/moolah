defmodule MoolahWeb.TelemetryTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias MoolahWeb.Telemetry

  describe "telemetry configuration" do
    test "module exports metrics function" do
      assert function_exported?(Telemetry, :metrics, 0)
    end

    test "metrics/0 returns a list of telemetry metrics" do
      metrics = Telemetry.metrics()
      assert is_list(metrics)
      assert Enum.any?(metrics)
    end

    test "all metrics have required fields" do
      metrics = Telemetry.metrics()

      for metric <- metrics do
        # Every metric must have an event_name
        assert is_list(metric.event_name)
        assert metric.event_name != []

        # Every metric has a name derived from event_name
        assert is_list(metric.name)
        assert metric.name != []

        # Metrics should have a measurement (function or atom)
        assert is_function(metric.measurement) or is_atom(metric.measurement)
      end
    end

    test "metrics include phoenix endpoint metrics" do
      metrics = Telemetry.metrics()
      event_names = Enum.map(metrics, & &1.event_name)

      assert [:phoenix, :endpoint, :start] in event_names
      assert [:phoenix, :endpoint, :stop] in event_names
    end

    test "metrics include database query metrics" do
      metrics = Telemetry.metrics()
      event_names = Enum.map(metrics, & &1.event_name)

      assert [:moolah, :repo, :query] in event_names
    end

    test "metrics include VM metrics" do
      metrics = Telemetry.metrics()
      event_names = Enum.map(metrics, & &1.event_name)

      assert [:vm, :memory] in event_names
      assert [:vm, :total_run_queue_lengths] in event_names
    end

    test "metrics include phoenix router metrics" do
      metrics = Telemetry.metrics()
      event_names = Enum.map(metrics, & &1.event_name)

      assert [:phoenix, :router_dispatch, :start] in event_names
      assert [:phoenix, :router_dispatch, :stop] in event_names
      assert [:phoenix, :router_dispatch, :exception] in event_names
    end

    test "multiple metrics are configured" do
      metrics = Telemetry.metrics()
      # Ensure we have more than a single metric configured
      assert Enum.count(metrics) > 1
    end
  end
end
