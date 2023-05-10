require "../spec_helper"
require "io/memory"
require "log"
require "../../src/opentelemetry/instrumentation/crystal/log"
require "json"

describe Log, tags: "Log" do
  it "can log as normal when there isn't an active span." do
    backend = Log::MemoryBackend.new
    message = "I am a message, and there is no span."
    Log.setup(:info, backend)
    Log.info { message }

    backend.entries.first.message.should eq message
  end

  it "can log as normal and send attach the log as an event to a span" do
    checkout_config do
      memory = IO::Memory.new
      OpenTelemetry.configure do |config|
        config.service_name = "Crystal OTel Instrumentation - HTTP::Server"
        config.service_version = "1.0.0"
        config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
      end
      backend = Log::MemoryBackend.new
      message = "I am a message, and there is an active span."
      Log.setup(:info, backend)

      OpenTelemetry.trace.in_span("logging test span") do |_span|
        Log.info { message }
      end

      backend.entries.first.message.should eq message
      _client_traces, server_traces = FindJson.from_io(memory)
      server_traces[0]["spans"][0]["name"].should eq "logging test span"
      server_traces[0]["spans"][0]["events"].size.should be > 0
      server_traces[0]["spans"][0]["events"][0]["name"].should eq "Log.INFO"
      server_traces[0]["spans"][0]["events"][0]["attributes"]["message"].as_s.should contain(message)
    end
  end
end
