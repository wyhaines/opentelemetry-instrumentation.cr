require "../spec_helper"
require "http/server"
require "http/client"
require "../../src/opentelemetry/instrumentation/crystal/http_server"
require "io/memory"
require "json"

describe HTTP::Server, tags: ["HTTP::Server"] do
  it_may_focus_and_it "should have instrumented HTTP::Server" do
    Tracer::TRACED_METHODS_BY_RECEIVER[HTTP::Server]?.should be_truthy
  end

  it "should generate otel traces" do
    memory = IO::Memory.new
    OpenTelemetry.configure do |config|
      config.service_name = "Crystal OTel Instrumentation - HTTP::Server"
      config.service_version = "1.0.0"
      config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
    end

    address = nil

    spawn(name: "HTTP Server") do
      # Create a simple little server, with a simple little handler.
      server = HTTP::Server.new do |context|
        context.response.content_type = "text/plain"
        context.response.print "Hello world!"
      end

      # Ensure that the server is shut down, even if something weird happens and
      # the specs are slow to run or get stuck or something.
      spawn(name: "Kill Server") do
        sleep 2
        server.close
      end

      # Start the server.
      address = server.bind_tcp 8080
      server.listen
    end

    # Send requests to the server. These will generate OTel traces.
    2.times do
      HTTP::Client.get("http://127.0.0.1:8080")
      sleep((rand() * 100) / 1000)
    end

    memory.rewind
    strings = memory.gets_to_end
    json_finder = FindJson.new(strings)

    traces = [] of JSON::Any
    while json = json_finder.pull_json
      traces << JSON.parse(json)
    end

    traces[0]["spans"][0]["name"].should eq "HTTP::Server connection"
    traces[0]["resource"]["service.name"].should eq "Crystal OTel Instrumentation - HTTP::Server"
    traces[0]["spans"][0]["kind"].should eq 2 # Unspecified = 0 | Internal = 1 | Server = 2 | Client = 3 | Producer = 4 | Consumer = 5
    traces[0]["resource"]["service.version"].should eq "1.0.0"
    traces[0]["spans"][0]["attributes"]["http.method"].should eq "GET"
    traces[0]["spans"][0]["attributes"]["http.scheme"].should eq "http"

    traces[0]["spans"][1]["name"].should eq "Invoke handler Proc(HTTP::Server::Context, Nil)"
    traces[0]["spans"][1]["kind"].should eq 1
  end
end
