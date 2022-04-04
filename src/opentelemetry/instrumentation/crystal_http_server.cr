require "./instrument"
require "tracer"
require "defined"

if_defined?("HTTP::Server", <<-ECODE)
module OpenTelemetry::Instrumentation
  class CrystalHttpServer < OpenTelemetry::Instrumentation::Instrument
  end
end

class HTTP::Server
  trace("handle_client") do |method_name, phase|
    case phase
    when :before
      trace = OpenTelemetry.trace
    when :after
    end
  end
end
ECODE
