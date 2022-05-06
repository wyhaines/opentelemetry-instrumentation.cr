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
      class Redis::Strategy::SingleStatement < Redis::Strategy::Base
        OpenTelemetry.trace.in_span("Redis #{request[0..1]?.join(' ')}") do |span|
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
            @socket.class.name # Generic fallback, but is unlikely to happen
          end

          span["db.system"] = "redis"
          span["db.statement"] = command.map(&.inspect_unquoted).join(' ')
          span["db.redis.database_index"] = (@uri.path.presence || "/")[1..].presence
        end
      end
    end
  end
end
