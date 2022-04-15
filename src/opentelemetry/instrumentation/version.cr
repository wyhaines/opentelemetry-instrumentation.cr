module OpenTelemetry
  module Instrumentation
    {% begin %}
    VERSION = {{ read_file("#{__DIR__}/../../../VERSION").chomp }}
    {% end %}
  end
end
