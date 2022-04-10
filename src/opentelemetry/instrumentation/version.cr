module OpenTelemetry
  module Instrumentation
    {% begin %}
    # Pull the version directly from Git.
    VERSION = {{ read_file("#{__DIR__}/../../../VERSION").chomp }}
    {% end %}
  end
end
