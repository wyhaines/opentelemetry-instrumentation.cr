require "../spec_helper"
require "http/server"
require "http/client"
require "../../src/opentelemetry/instrumentation/crystal/http_server"
require "io/memory"
require "json"

HTTP_SERVER_TEST_PORT = [8080]

1000.times do |t|
  begin
    server = HTTP::Server.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello world!"
    end

    try_port = 8080 + t
    server.bind_tcp try_port

    HTTP_SERVER_TEST_PORT[0] = try_port
    server.close
    break
  rescue ex
    # NOP
  end
end

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
      address = server.bind_tcp HTTP_SERVER_TEST_PORT[0]
      server.listen
    end

    sleep 1

    # Send requests to the server. These will generate OTel traces.
    1.times do
      HTTP::Client.get("http://127.0.0.1:#{HTTP_SERVER_TEST_PORT[0]}/")
      sleep((rand() * 100) / 1000)
    end

    client_traces, server_traces = FindJson.from_io(memory)

    {% begin %}
    {% if flag? :DEBUG %}
    pp client_traces
    pp "---------------"
    pp server_traces
    {% end %}
    {% end %}

    client_traces[0]["spans"][0]["name"].should eq("HTTP::Client GET")
    client_traces[0]["spans"][0]["kind"].should eq 3
    client_traces[0]["spans"][0]["attributes"]["http.url"].should eq "http://127.0.0.1:#{HTTP_SERVER_TEST_PORT[0]}/"

    server_traces[0]["spans"][0]["name"].should eq "HTTP::Server connection"
    server_traces[0]["resource"]["service.name"].should eq "Crystal OTel Instrumentation - HTTP::Server"
    server_traces[0]["spans"][0]["kind"].should eq 2 # Unspecified = 0 | Internal = 1 | Server = 2 | Client = 3 | Producer = 4 | Consumer = 5
    server_traces[0]["resource"]["service.version"].should eq "1.0.0"
    server_traces[0]["spans"][0]["attributes"]["net.peer.ip"].should eq "127.0.0.1"

    server_traces[1]["spans"][0]["name"].should eq "GET /"
    server_traces[1]["spans"][0]["attributes"]["http.method"].should eq "GET"
    server_traces[1]["spans"][0]["attributes"]["http.scheme"].should eq "http"
    server_traces[1]["spans"][0]["parentSpanId"].should eq client_traces[0]["spans"][0]["spanId"]

    server_traces[1]["spans"][1]["name"].should eq "Invoke handler Proc(HTTP::Server::Context, Nil)"
    server_traces[1]["spans"][1]["kind"].should eq 1
  end
end
