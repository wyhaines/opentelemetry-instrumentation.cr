require "tracer"

module OpenTelemetry
  module Instrumentation
    abstract class Instrument
      macro inherited
        Registry.register(self)
      end

      def self.instrument_name
        self.name.gsub(/^OpenTelemetry::Instrumentation::/, "")
      end
    end
  end
end
