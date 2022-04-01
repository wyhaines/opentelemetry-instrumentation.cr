require "./instrument"
require "tracer"

module OpenTelemetry::Instrumentation
  class CrystalHttpServer < OpenTelemetry::Instrumentation::Instrument
  end
end