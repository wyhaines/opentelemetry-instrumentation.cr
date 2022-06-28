require "./spec_helper"
require "../src/opentelemetry-instrumentation/log_backend"

describe OpenTelemetry::Instrumentation::LogBackend, tags: ["LogBackend"] do
  if Spec.tags.try(&.includes?("LogBackend"))
    it "should add the log to the existing span" do
      checkout_config do
        memory = IO::Memory.new
        OpenTelemetry.configure do |config|
          config.service_name = "Crystal OTel Instrumentation - OpenTelemetry::Instrumentation::LogBackend"
          config.service_version = "1.0.0"
          config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
        end

        random_source = Random::DEFAULT.base64
        ::Log.setup(sources: random_source, level: Log::Severity::Trace, backend: OpenTelemetry::Instrumentation::LogBackend.new)

        OpenTelemetry.trace.in_span("Fake Span") do |_span|
          exception = Exception.new("Oh no!")
          ::Log.with_context do
            ::Log.context.set(context: 42)
            ::Log.context.set(fiber: Fiber.current.current_span.object_id.to_s)
            ::Log.for(random_source).warn(exception: exception, &.emit("Oh no!", data: "stuff"))
          end
        end

        _client_traces, server_traces = FindJson.from_io(memory)

        server_traces[0]["spans"][0]["kind"].should eq 1
        server_traces[0]["spans"][0]["name"].should eq "Fake Span"
        server_traces[0]["spans"][0]["events"][0]["attributes"]["data"].should eq "stuff"
        server_traces[0]["spans"][0]["events"][0]["attributes"]["context"].should eq 42
      end
    end
  end
end
