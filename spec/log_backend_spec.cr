require "./spec_helper"
require "../src/opentelemetry-instrumentation/log_backend"

describe OpenTelemetry::Instrumentation::LogBackend do
  it "should add the log to the existing span" do
    memory = IO::Memory.new
    OpenTelemetry.configure do |config|
      config.service_name = "Crystal OTel Instrumentation - OpenTelemetry::Instrumentation::LogBackend"
      config.service_version = "1.0.0"
      config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
    end

    random_source = Random::DEFAULT.base64
    ::Log.setup(sources: random_source, level: Log::Severity::Trace, backend: OpenTelemetry::Instrumentation::LogBackend.new)

    trace = OpenTelemetry.trace
    trace.in_span("Fake Span") do |_span|
      exception = Exception.new("Oh no!")
      ::Log.with_context do
        ::Log.context.set(context: 42)
        ::Log.for(random_source).warn(exception: exception, &.emit("Oh no!", data: "stuff"))
      end
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
    traces[0]["spans"][0]["events"][0]["attributes"]["data"].should eq "stuff"
    traces[0]["spans"][0]["events"][0]["attributes"]["context"].should eq 42
  end
end
