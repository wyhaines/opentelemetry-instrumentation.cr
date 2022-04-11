require "../instrument"
require "db"

# # OpenTelemetry::Instrumentation::CrystalDB
# ### Instruments
#   * DB::Statement
#
# ### Reference: [https://path.to/package_documentation.html](https://path.to/package_documentation.html)
#
# Description of the instrumentation provided, including any nuances, caveats, instructions, or warnings.
#
# ## Methods Affected
#
# No methods are being overridden. The DB package provides a built-in way of wrapping queries, via
# the `DB::Statement#def_around_query_or_exec` macro. This functionality simply leverages that.
#
# [http://crystal-lang.github.io/crystal-db/api/latest/DB/Statement.html](http://crystal-lang.github.io/crystal-db/api/latest/DB/Statement.html#def_around_query_or_exec%28%26block%29-macro)
#
struct OpenTelemetry::InstrumentationDocumentation::CrystalDB
end

unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_DB") do
  if_defined?(DB::Statement) do
    module OpenTelemetry::Instrumentation
      class CrystalDB < OpenTelemetry::Instrumentation::Instrument
        {% begin %}
        alias DB::Types = {% for type in DB::Any.union_types %}Array({{ type.id }}) | {% end %}DB::Any
        {% end %}
        # One can add their own procs to this array (prepend them to the array) to add other data filtration"
        ArgFilters = [
          ->(arg : DB::Types) do
            arg.inspect
          end,
        ]
      end
    end

    if_version?(Crystal, :>=, "1.0.0") do
      class DB::Statement
        private def _normalize_scheme_(scheme)
          case scheme
          when "postgres"
            "postgresql"
            # There are probably others for which the scheme doesn't match the OTel prescribed
            # labels to be used. Clauses for them should go here.
            # See https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/semantic_conventions/database.md)
          else
            scheme.to_s
          end
        end

        private def _normalize_transport_data_(connection_uri)
          scheme = _normalize_scheme_(connection_uri.scheme)
          case scheme
          when "sqlite3"
            {
              "net.transport": "uds",
              "socket.path":   connection_uri.host.to_s + connection_uri.path.to_s,
            }
          else
            {
              "net.transport": "ip_tcp",
              "net.peer.name": connection_uri.host,
              "net.peer.port": connection_uri.port,
            }
          end
        end

        def_around_query_or_exec do |args|
          # Place the span in the existing trace, if any. If there is currently no trace running, then
          # create a new trace.
          unless trace = OpenTelemetry::Trace.current_trace
            trace = OpenTelemetry.trace
          end

          query = command.compact
          operation = query.strip[0...query.index(' ')]                   # This is faster than a regex
          uri = connection.context.uri.dup.tap(&.password=("[FILTERED]")) # redact password from URI
          uri.path.lchop                                                  # This is dodgy; without doing this, the assignment below will sometimes get a garbled first few characters.
          db_name = uri.path.lchop
          trace.in_span("#{db_name}->#{operation.upcase}") do |span| # My kingdom for a SQL parser that can extract table names from a SQL query!
            query_args = [] of String
            args.each do |arg|
              OpenTelemetry::Instrumentation::CrystalDB::ArgFilters.each do |filter|
                filter_result = filter.call(arg)
                arg = filter_result if filter_result
              end

              arg = arg.to_s unless arg.is_a?(String)
              query_args << arg
            end

            transport_data = _normalize_transport_data_(uri)
            transport_data.each do |key, value|
              span.set_attribute(key.to_s, value.to_s)
            end

            span["db.system"] = _normalize_scheme_(uri.scheme)
            span["db.connection_string"] = uri.to_s
            span["db.user"] = uri.user.to_s if uri.user
            span["db.name"] = db_name
            span["db.statement"] = command
            span["db.query_args"] = query_args
            span["db.operation"] = operation
            span.kind = OpenTelemetry::Span::Kind::Client

            yield # Perform the actual query
          end
        end
      end
    end
  end
end
