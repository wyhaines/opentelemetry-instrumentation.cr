require "../spec_helper"
require "http/server"
require "http/client"
require "../../src/opentelemetry/instrumentation/crystal_http_server"

describe HTTP::Server, tags: ["HTTP::Server"] do
  it "should have instrumented HTTP::Server" do
    Tracer::TRACED_METHODS_BY_RECEIVER[HTTP::Server]?.should be_truthy
  end

  it "should generate otel traces" do
    OpenTelemetry.configure do |config|
      config.service_name = "Crystal OTel Instrumentation - HTTP::Server"
      config.service_version = "1.0.0"
      config.exporter = OpenTelemetry::Exporter.new(variant: :stdout) do |exporter|
        exporter.as(OpenTelemetry::Exporter::Stdout)
      end
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
      puts "Listening on http://#{address}"
      server.listen
    end

    2.times do
      HTTP::Client.get("http://127.0.0.1:8080")
    end
    sleep 2
  end
end
