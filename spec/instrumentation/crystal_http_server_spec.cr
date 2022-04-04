require "../spec_helper"
require "http/server"
require "../../src/opentelemetry/instrumentation/crystal_http_server"

describe HTTP::Server, tags: ["HTTP::Server", "included"] do
  it "should have instrumented HTTP::Server" do
    Tracer::TRACED_METHODS_BY_RECEIVER[HTTP::Server]?.should be_truthy
  end
end
