require "../instrument"
require "../../../opentelemetry-instrumentation/log_backend"

# # OpenTelemetry::Instrumentation::CrystalLog
#
# ### Instruments
#   * Log
#
# ### Reference: [https://crystal-lang.org/api/1.4.0/Log.html](https://crystal-lang.org/api/1.4.0/Log.html)
#
# This instrument will record logs generated with `Log` as events in the current span. If there
# is no current span, the instrument is a NOP. In either case, configured logging then procedes
# as expected.
#
# ## Methods Affected
#
# * Log#trace
# * Log#debug
# * Log#info
# * Log#notice
# * Log#warn
# * Log#error
# * Log#fatal
#
struct OpenTelemetry::InstrumentationDocumentation::CrystalLog
end

unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_LOG") do
  if_defined?(::Log) do
    # :nodoc:
    module OpenTelemetry::Instrumentation
      class CrystalLog < OpenTelemetry::Instrumentation::Instrument
      end
    end

    if_version?(Crystal, :>=, "1.0.0") do
      class Log
        {% for method, severity in {
                                     trace:  Severity::Trace,
                                     debug:  Severity::Debug,
                                     info:   Severity::Info,
                                     notice: Severity::Notice,
                                     warn:   Severity::Warn,
                                     error:  Severity::Error,
                                     fatal:  Severity::Fatal,
                                   } %}
        def {{method.id}}(*, exception : Exception? = nil)
          severity = Severity.new({{severity}})
          if (span = OpenTelemetry::Trace.current_span) && level <= severity
            # There is an active span, so attach this log
            dsl = Emitter.new(@source, severity, exception)
            result = yield dsl
            entry =
              case result
              when Entry
                result
              else
                dsl.emit(result.to_s)
              end
            backend = @backend
            span.add_event("Log.#{entry.severity.label}#{" - #{entry.source}" unless entry.source.empty?}") do |event|
              OpenTelemetry::Instrumentation::LogBackend.apply_log_entry(entry, event)
            end

            return unless backend

            backend.dispatch entry
          else
            previous_def { |e| yield e }
          end
        end
        {% end %}
      end
    end
  end
end
