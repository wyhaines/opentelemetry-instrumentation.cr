require "../spec_helper"
require "defined"

describe "HTTP::Server", tags: ["HTTP::Server", "not_included"] do
  if defined?("HTTP::Server")
    it "should not be defined" do
      Tracer::TRACED_METHODS_BY_RECEIVER[HTTP::Server]?.should be_nil
    end
  else
    it "is not defined" do
      (!defined?("HTTP::Server")).should be_true
    end
  end
end