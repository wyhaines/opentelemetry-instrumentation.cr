require "../instrument"

# # OpenTelemetry::Instrumentation::StefanWilleRedis
#
# ### Instruments
#   *
#
# ### Reference: [http://stefanwille.github.io/crystal-redis/](http://stefanwille.github.io/crystal-redis/)
#
# Description of the instrumentation provided, including any nuances, caveats, instructions, or warnings.
#
# ## Methods Affected
#
# *
#
struct OpenTelemetry::InstrumentationDocumentation::StefanWilleRedis
end

unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_STEFANWILLE_REDIS") do
  if_defined?(Redis::Strategy::Transaction) do
    module OpenTelemetry::Instrumentation
      class InstrumentName < OpenTelemetry::Instrumentation::Instrument
      end
    end

    unless_defined?(Redis::VERSION) do
      # Monkeypatch a few things so that useful information is available for the spans.
      # TODO: See if the maintainers would like some version of these patches contributed back to the main project.
      class Redis
        getter database : Int32? = nil
        getter uri : URI? = nil

        def initialize(@host = "localhost", @port = 6379, @unixsocket : String? = nil, @password : String? = nil,
                       @database : Int32? = nil, url = nil, @ssl = false, @ssl_context : OpenSSL::SSL::Context::Client? = nil,
                       @dns_timeout : Time::Span? = nil, @connect_timeout : Time::Span? = nil, @reconnect = true, @command_timeout : Time::Span? = nil,
                       @namespace : String = "")
          if url
            uri = @uri = URI.parse(url)
            path = uri.path
            @database = path[1..-1].to_i if path && path.size > 1
          end

          previous_def
        end

        private def connect
          previous_def

          if cnxn = @connection
            cnxn.uri = @uri
            cnxn.database = @database
          end
        end
      end

      class Redis::Connection
        property database : Int32? = nil
        property uri : URI? = nil
      end

      class Redis::Future
        property trace_parent : OpenTelemetry::Propagation::TraceContext::TraceParent? = nil
      end

      class Redis::Strategy::SingleStatement
        trace("command") do
          OpenTelemetry.trace.in_span("Redis #{request[0..1]? ? request[0..1].join(' ') : ""}") do |span|
            span.client!
            socket = @connection.@socket
            span["net.peer.name"] = case socket
                                    when UNIXSocket
                                      socket.path
                                    when TCPSocket, OpenSSL::SSL::Socket::Client
                                      socket.hostname.presence || socket.remote_address.address
                                    else
                                      ""
                                    end

            span["net.transport"] = case socket
                                    when UNIXSocket
                                      "Unix"
                                    when TCPSocket, OpenSSL::SSL::Socket::Client
                                      "ip_tcp"
                                    else
                                      socket.class.name # Generic fallback, but is unlikely to happen
                                    end

            span["db.system"] = "redis"
            span["db.statement"] = request.map(&.to_s.inspect_unquoted).join(' ')
            span["db.redis.database_index"] = (@connection.@uri.try(&.path.presence) || "/")[1..].presence.to_s

            previous_def
          end
        end
      end

      class Redis::Strategy::Pipeline
        trace("command") do
          OpenTelemetry.trace.in_span("Redis #{request[0..1]? ? request[0..1].join(' ') : ""}") do |span|
            span.producer!
            socket = @connection.@socket
            span["net.peer.name"] = case socket
                                    when UNIXSocket
                                      socket.path
                                    when TCPSocket, OpenSSL::SSL::Socket::Client
                                      socket.hostname.presence || socket.remote_address.address
                                    else
                                      ""
                                    end

            span["net.transport"] = case socket
                                    when UNIXSocket
                                      "Unix"
                                    when TCPSocket, OpenSSL::SSL::Socket::Client
                                      "ip_tcp"
                                    else
                                      socket.class.name # Generic fallback, but is unlikely to happen
                                    end

            span["db.system"] = "redis"
            span["db.statement"] = request.map(&.to_s.inspect_unquoted).join(' ')
            span["db.redis.database_index"] = (@connection.@uri.try(&.path.presence) || "/")[1..].presence.to_s

            future = previous_def

            future.trace_parent = OpenTelemetry::Propagation::TraceContext::TraceParent.from_span_context(span.context)

            future
          end
        end
      end

      class Redis::Future
        trace("value=") do
          OpenTelemetry.trace.in_span("Redis Result Returned") do |span|
            span.consumer!
            parent = OpenTelemetry::Span.build do |pspan|
              pspan.is_recording = false

              if tptid = trace_parent.try &.trace_id
                pspan.context.trace_id = tptid
                span.context.trace_id = tptid
              end
              if tpsid = trace_parent.try &.span_id
                pspan.context.span_id = tpsid
              end
            end
            span.parent = parent

            previous_def
          end
        end
      end
    end
  end
end
