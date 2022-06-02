require "../spec_helper"
require "../../src/opentelemetry/instrumentation/frameworks/spider-gazelle"

describe ActionController::Router::RouteHandler do
  it "should have installed the Lucky instrumetation" do
    OpenTelemetry::Instrumentation::Registry.instruments.includes?(OpenTelemetry::Instrumentation::Framework::SpiderGazelle).should be_true
  end

  it "should add the route to the existing span" do
    memory = IO::Memory.new
    OpenTelemetry.configure do |config|
      config.service_name = "Crystal OTel Instrumentation - ActionController::Router::RouteHandler"
      config.service_version = "1.0.0"
      config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
    end

    trace = OpenTelemetry.trace
    trace.in_span("Fake Request") do |_span|
      handler = ActionController::Router::RouteHandler.new
      handler.call(ActionController::Context.new)
    end

    memory.rewind
    strings = memory.gets_to_end
    json_finder = FindJson.new(strings)

    traces = [] of JSON::Any
    while json = json_finder.pull_json
      traces << JSON.parse(json)
    end

    traces[0]["spans"][0]["kind"].should eq 1
    traces[0]["spans"][0]["name"].should eq "Fake Request"
    traces[0]["spans"][0]["attributes"]["http.route"].should eq "Home::Index"
  end
end
