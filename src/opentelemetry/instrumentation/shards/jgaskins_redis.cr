require "../instrument"

# # OpenTelemetry::Instrumentation::JGaskinsRedis
#
# ### Instruments
#   * Redis::Connection
#
# ### Reference: [https://github.com/jgaskins/redis](https://github.com/jgaskins/redis)
#
# This instruments the jgaskins Redis shard, which is a simple, pure Crystal shard for
# interacting with a Redis server. Instrumentation of this shard is accomplished by wrapping
# just a single method.
#
# ## Methods Affected
#
# * Redis::Connection#run
#
struct OpenTelemetry::InstrumentationDocumentation::JGaskinsRedis
end

unless_disabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_JGASKINS_REDIS") do
  # The stefanwille shard doesn't define this constant. This is unfortunate, but it does (currently)
  # make it convenient to help differentiate between the two shards.
  if_defined?(Redis::VERSION) do
    # :nodoc:
    module OpenTelemetry::Instrumentation
      class JGaskinsRedis < OpenTelemetry::Instrumentation::Instrument
      end
    end

    if_version?(Redis, :>=, "0.3.1") do
      class Redis::Connection
        trace("run") do
          OpenTelemetry.trace.in_span("Redis #{command[0..1]? ? command[0..1].join(' ') : ""}") do |span|
            span.client!
            span["net.peer.name"] = @uri.host.to_s
            span["net.transport"] = case socket = @socket
                                    when UNIXSocket
                                      "Unix"
                                    when TCPSocket, OpenSSL::SSL::Socket::Client
                                      "ip_tcp"
                                    else
                                      socket.class.name # Generic fallback, but is unlikely to happen
                                    end

            span["db.system"] = "redis"
            span["db.statement"] = command.map(&.to_s.inspect_unquoted).join(' ')
            span["db.redis.database_index"] = (@uri.path.presence || "/")[1..].presence.to_s

            previous_def
          end
        end
      end
    end
  end
end
