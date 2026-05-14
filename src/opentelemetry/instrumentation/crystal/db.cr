require "../instrument"

# # OpenTelemetry::Instrumentation::CrystalDB
#
# ### Instruments
#
#   * DB::Statement
#
# ### Reference: [http://crystal-lang.github.io/crystal-db/api/latest/DB.html](http://crystal-lang.github.io/crystal-db/api/latest/DB.html)
#
# This instrumentation will trace any database interactions that subclass from the Crystal standard `DB` class/shard.
#
# ## Methods Affected
#
# No methods are being overridden. The DB package provides a built-in way of wrapping queries, via
# the `DB::Statement#def_around_query_or_exec` macro. This functionality simply leverages that.
#
# [http://crystal-lang.github.io/crystal-db/api/latest/DB/Statement.html](http://crystal-lang.github.io/crystal-db/api/latest/DB/Statement.html#def_around_query_or_exec%28%26block%29-macro)
#
# ## Configuration
#
# - `OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_DB`
#
#   If set, this will **disable** the `DB` instrumentation.
#
# ## Version Restrictions
#
# * DB >= 0.10.0
#
struct OpenTelemetry::InstrumentationDocumentation::CrystalDB
end

unless_disabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_DB") do
  if_defined?(::DB::Statement) do
    require "db/version" # The VERSION doesn't appear to be required by default.
  end

  if_defined?(::DB::Statement) do
    # :nodoc:
    module OpenTelemetry::Instrumentation
      class CrystalDB < OpenTelemetry::Instrumentation::Instrument
        def self.filter(arg)
          arg.inspect
        end

        {% begin %}
        alias DB::Types = {% for type in DB::Any.union_types %}Array({{ type.id }}) | {% end %}::DB::Any | UUID | Array(UUID)
        {% end %}
      end
    end

    if_version?(DB, :>=, "0.10.0") do
      if_version?(DB, :<, "0.12.0") do
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
            query = command.compact
            operation = query.strip[0...query.index(' ')]                   # This is faster than a regex
            uri = connection.context.uri.dup.tap(&.password=("[FILTERED]")) # redact password from URI
            uri.path.lchop                                                  # This is dodgy; without doing this, the assignment below will sometimes get a garbled first few characters.
            db_name = uri.path.lchop
            OpenTelemetry.in_span("#{db_name}->#{operation.upcase}") do |span| # My kingdom for a SQL parser that can extract table names from a SQL query!
              query_args = [] of String
              args.each do |arg|
                # OpenTelemetry::Instrumentation::CrystalDB::ArgFilters.each do |filter|
                #   filter_result = filter.call(arg)
                #   arg = filter_result if filter_result
                # end
                arg = OpenTelemetry::Instrumentation::CrystalDB.filter(arg)

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

      # DB 0.12.0 (June 2023) refactored the connection factory and removed the public
      # `uri` getter from both `ConnectionContext` and `Database`. The URI is now consumed
      # by `Driver#connection_builder(uri)` and dropped on the floor. We re-introduce it
      # by stashing the URI on the Database/Connection at build time and resolving it
      # from the Statement when we need to emit span attributes.
      if_version?(DB, :>=, "0.12.0") do
        class DB::Database
          property connection_uri : URI? = nil
        end

        abstract class DB::Connection
          property connection_uri : URI? = nil
        end

        # Both `DB.open` and `DB.connect` (block and non-block, URI and String overloads)
        # eventually call these two private class methods, so wrapping them with
        # `previous_def` is sufficient to capture the URI for every entry point.
        # Note: `previous_def` against a `private def self.x` on a reopened module is
        # the load-bearing trick here — verified working on Crystal 1.x. If a future
        # compiler tightens this, both overrides would fail to compile (loud, easy
        # to catch in CI) and we would need to wrap the public `DB.open`/`DB.connect`
        # overloads instead.
        module DB
          private def self.build_database(uri : URI)
            db = previous_def
            db.connection_uri = uri
            db
          end

          private def self.build_connection(uri : URI)
            conn = previous_def
            conn.connection_uri = uri
            conn
          end
        end

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

          private def _resolve_connection_uri_ : URI?
            if cu = connection.connection_uri
              return cu
            end
            ctx = connection.context
            ctx.is_a?(DB::Database) ? ctx.connection_uri : nil
          end

          def_around_query_or_exec do |args|
            query = command.compact
            space_index = query.index(' ')
            operation = space_index ? query.strip[0...space_index] : query.strip

            resolved = _resolve_connection_uri_
            if resolved
              uri = resolved.dup
              uri.password = "[FILTERED]" if uri.password
              if query_string = uri.query
                params = HTTP::Params.parse(query_string)
                uri.query = HTTP::Params.build do |builder|
                  params.each do |k, v|
                    builder.add(k, k.downcase == "password" ? "[FILTERED]" : v)
                  end
                end
              end
              db_name = uri.path.lchop
            else
              uri = nil
              db_name = ""
            end

            OpenTelemetry.in_span("#{db_name}->#{operation.upcase}") do |span|
              query_args = [] of String
              args.each do |arg|
                arg = OpenTelemetry::Instrumentation::CrystalDB.filter(arg)
                arg = arg.to_s unless arg.is_a?(String)
                query_args << arg
              end

              if uri
                transport_data = _normalize_transport_data_(uri)
                transport_data.each do |key, value|
                  span.set_attribute(key.to_s, value.to_s)
                end

                span["db.system"] = _normalize_scheme_(uri.scheme)
                span["db.connection_string"] = uri.to_s
                span["db.user"] = uri.user.to_s if uri.user
                span["db.name"] = db_name
              end
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
end
