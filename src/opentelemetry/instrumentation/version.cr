module OpenTelemetry
  module Instrumentation
    {% begin %}
    VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
    {% end %}
  end
end
