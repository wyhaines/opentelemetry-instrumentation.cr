require "opentelemetry-api"
require "io/memory"
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
      io = IO::Memory.new
      ::Log::ShortFormat.format(entry, io)

      span.add_event("Log.#{entry.severity.label}#{!entry.source.empty? ? " - #{entry.source}" : ""}") do |event|
        # TODO: Add context
        # event.attributes = entry.context.each_with_object({} of String => ValueTypes) do |(key, value), attributes|
        #   if value.is_a? ValueTypes
        #     attributes[key.to_s] = value
        #   end
        # end

        event["message"] = io.rewind.gets_to_end
        if exception = entry.exception
          event["exception"] = exception.to_s
          event["backtrace"] = exception.backtrace.join("\n")
        end
        event["source"] = entry.source if !entry.source.empty?
        event["timestamp"] = entry.timestamp.to_s
      end
    end
  end
end
