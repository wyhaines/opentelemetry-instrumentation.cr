require "opentelemetry-api"
require "log"
require "log/backend"

# # OpenTelemetry::Instrumentation::LogBackend
#
# Provides a simple implementation of `Log::Backend`.
#
# If a `Log` call takes place within a span, the log and its context are added as an event.
#
# ```
# require "opentelemetry-instrumentation/log_backend"
# Log.builder.bind("*", Log::Severity::Warn, OpenTelemetry::Instrumentation::LogBackend.new)
# ```
class OpenTelemetry::Instrumentation::LogBackend < ::Log::Backend
  def write(entry : ::Log::Entry)
    if (span = OpenTelemetry::Trace.current_span)
      message = String.build { |io| ::Log::ShortFormat.format(entry, io) }
      span.add_event("Log.#{entry.severity.label}#{" - #{entry.source}" unless entry.source.empty?}") do |event|
        entry.context.each do |key, value|
          if (raw = value.raw).is_a?(ValueTypes)
            event[key.to_s] = raw
          end
        end

        event["message"] = message
        if exception = entry.exception
          event["exception"] = exception.to_s
          if backtrace = exception.backtrace?.try(&.join('\n'))
            event["backtrace"] = backtrace
          end
        end
        event["source"] = entry.source if !entry.source.empty?
        event["timestamp"] = entry.timestamp.to_s
      end
    end
  end
end
