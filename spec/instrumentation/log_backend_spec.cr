require "../spec_helper"
require "../../src/opentelemetry/instrumentation/log_backend"

describe OpenTelemetry::Instrumentation::LogBackend do
  it "should add the log to the existing span" do
    memory = IO::Memory.new
    OpenTelemetry.configure do |config|
      config.service_name = "Crystal OTel Instrumentation - OpenTelemetry::Instrumentation::LogBackend"
      config.service_version = "1.0.0"
      config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
    end

    Log.builder.bind(source: "test-opentelemetry", level: Log::Severity::Warn, backend: OpenTelemetry::Instrumentation::LogBackend.new)

    trace = OpenTelemetry.trace
    trace.in_span("Fake Span") do |_span|
      exception = Exception.new("Oh no!")
      Log.for("test-opentelemetry").warn(exception: exception, &.emit("Oh no!", user_id: 42))
    end

    memory.rewind
    strings = memory.gets_to_end
    json_finder = FindJson.new(strings)

    traces = [] of JSON::Any
    while json = json_finder.pull_json
      traces << JSON.parse(json)
    end

    traces[0]["spans"][0]["kind"].should eq 1
    traces[0]["spans"][0]["name"].should eq "Fake Span"
    # traces[0]["spans"][0]["attributes"]["user_id"].should eq 42
  end
end
