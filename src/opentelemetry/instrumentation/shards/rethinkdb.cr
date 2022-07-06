require "../instrument"

# # OpenTelemetry::Instrumentation::RethinkDB
#
# ### Instruments
#   * RethinkDB::Connection
#   * RethinkDB::Connection::ResponseStream
#
# ### Reference: [https://github.com/kingsleyh/crystal-rethinkdb](https://github.com/kingsleyh/crystal-rethinkdb)
#
# ## Methods Affected
#
# - `RethinkDB::Connection#connect`
#
#   Trace the connection establishment to the database
#
# - `RethinkDB::Connection#authorise`
#
#   Trace authorisation with the database
#
# - `RethinkDB::Connection::ResponseStream#query_term`
#
#   `query_term` sends a ReQL query to the database and reads the response.
#
# - `RethinkDB::Connection::ResponseStream#query_continue`
#
#   `query_continue` follows a `query_term` and is primarily for lazily fetching
#   results from the query curso
#
struct OpenTelemetry::InstrumentationDocumentation::RethinkDB
end

# This allows opt-out of specific instrumentation at compile time, via environment variables.
# Refer to https://wyhaines.github.io/defined.cr/ for details about all supported check types.
unless_disabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_RETHINKDB") do
  if_defined?(RethinkDB::Connection) do
    module OpenTelemetry::Instrumentation
      class RethinkDB < OpenTelemetry::Instrumentation::Instrument
      end
    end

    module RethinkDB
      class Connection
        trace("connect") do
          OpenTelemetry.in_span("RethinkDB Connect") do |span|
            span["user"] = user
            span["db"] = db
            span["host"] = host
            span["port"] = port
            previous_def
          end
        end

        trace("authorise") do
          OpenTelemetry.in_span("RethinkDB Authorise") do |span|
            span["user"] = user
            span["db"] = db
            span["host"] = host
            span["port"] = port
            previous_def
          end
        end

        struct ResponseStream
          trace("query_term") do
            OpenTelemetry.in_span("RethinkDB Query") do |span|
              span["user"] = @conn.user
              span["db"] = @conn.db
              span["host"] = @conn.host
              span["port"] = @conn.port
              previous_def
            end
          end

          trace("query_continue") do
            OpenTelemetry.in_span("RethinkDB Query Continue") do |span|
              span["user"] = @conn.user
              span["db"] = @conn.db
              span["host"] = @conn.host
              span["port"] = @conn.port
              previous_def
            end
          end
        end
      end
    end
  end
end
