require "../spec_helper"
require "io/memory"
require "log"
require "../../src/opentelemetry/instrumentation/crystal/log"
require "json"

describe Log do
  it "can log as normal when there isn't an active span." do
    backend = Log::MemoryBackend.new
    message = "I am a message, and there is no span."
    Log.setup(:info, backend)
    Log.info { message }

    backend.entries.first.message.should eq message
  end

  it "can log as normal and send attach the log as an event to a span" do
    memory = IO::Memory.new
    OpenTelemetry.configure do |config|
      config.service_name = "Crystal OTel Instrumentation - HTTP::Server"
      config.service_version = "1.0.0"
      config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
    end
    backend = Log::MemoryBackend.new
    message = "I am a message, and there is an active span."
    Log.setup(:info, backend)

    trace = OpenTelemetry.trace
    trace.in_span("logging test span") do |span|
      Log.info {message }
    end

    backend.entries.first.message.should eq message
    json = JSON.parse(memory.rewind.gets_to_end)
    
    json["spans"][0]["name"].should eq "logging test span"
    json["spans"][0]["events"][0]["name"].should eq "Log.INFO"
    json["spans"][0]["events"][0]["attributes"]["message"].as_s.should contain(message)
  end
end