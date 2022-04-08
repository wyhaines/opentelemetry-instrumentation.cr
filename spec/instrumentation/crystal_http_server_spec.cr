require "../spec_helper"
require "http/server"
require "http/client"
require "../../src/opentelemetry/instrumentation/crystal_http_server"
require "io/memory"
require "json"

describe HTTP::Server, tags: ["HTTP::Server"] do
  it "should have instrumented HTTP::Server" do
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
      server = HTTP::Server.new do |context|
        context.response.content_type = "text/plain"
        context.response.print "Hello world!"
      end

      spawn(name: "Kill Server") do
        sleep 2
        server.close
      end

      address = server.bind_tcp 8080
      server.listen
    end

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
    traces[0]["spans"][0]["attributes"]["service.name"].should eq "Crystal OTel Instrumentation - HTTP::Server"
    traces[0]["spans"][0]["kind"].should eq "SERVER"
    traces[0]["spans"][0]["attributes"]["service.version"].should eq "1.0.0"
    traces[0]["spans"][0]["attributes"]["http.method"].should eq "GET"
    traces[0]["spans"][0]["attributes"]["http.scheme"].should eq "http"

    traces[0]["spans"][1]["name"].should eq "Invoke handler Proc(HTTP::Server::Context, Nil)"
    traces[0]["spans"][1]["kind"].should eq "INTERNAL"
  end
end
