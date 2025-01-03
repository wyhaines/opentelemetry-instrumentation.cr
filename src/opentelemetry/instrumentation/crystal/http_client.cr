require "../instrument"

# # OpenTelemetry::Instrumentation::CrystalHttpClient
#
# ### Instruments
#
#   * HTTP::Client
#
# ### Reference: [https://crystal-lang.org/api/1.4.1/HTTP/Client.html](https://crystal-lang.org/api/1.4.1/HTTP/Client.html)
#
# The HTTP::Client auto-instrumentation redefactirs the `HTTP::Client#io` method from a large method to a very small one,
# and moves most of the work into two new methods, `HTTP::Client#do_connect` and `HTTP::Client#do_connect_ssl`, which can
# then be instrumented, and can receive some additional code to capture some information which is normally discarded, but
# which the semantic conventions for HTTP spans calls for. It then uses a `#def_around_exec` block to complete the instrumentation.
#
# ## Configuration
#
# - `OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_HTTP_CLIENT`
#
#   If set, this will **disable** the instrumentation.
#
# ## Version Restrictions
#
# * Crystal >= 1.0.0
#
# ## Methods Affected
#
# - `HTTP::Client.io`
#
#   Refactored from a large method to a small method that calls `#do_connect`.
#
# - `HTTP::Client#do_connect`
#
#   Capture some information about the connection that is thrown away in the original method,
#   and the utilize it in the instrumentation wrapper that follows.
#
# - `HTTP::Client#do_connect_ssl`
#
#   Capture some information about the connection that is thrown away in the original method,
#   and the utilize it in the instrumentation wrapper that follows.
#
struct OpenTelemetry::InstrumentationDocumentation::CrystalHttpClient
end

# This allows opt-out of specific instrumentation at compile time, via environment variables.
# Refer to https://wyhaines.github.io/defined.cr/ for details about all supported check types.
unless_disabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_HTTP_CLIENT") do
  if_defined?(::HTTP::Client) do
    # This exists to record the instrumentation in the OpenTelemetry::Instrumentation::Registry,
    # which may be used by other code/tools to introspect the installed instrumentation.
    # :nodoc:
    module OpenTelemetry::Instrumentation
      class CrystalHttpClient < OpenTelemetry::Instrumentation::Instrument
      end
    end

    if_version?(Crystal, :>=, "1.0.0") do
      # NOTE: Offer these refactors as a PR to core Crystal.
      class HTTP::Client
        private def io
          io = @io
          return io if io
          unless @reconnect
            raise "This HTTP::Client cannot be reconnected"
          end

          do_connect
        end

        def do_connect
          hostname = @host.starts_with?('[') && @host.ends_with?(']') ? @host[1..-2] : @host
          io = TCPSocket.new hostname, @port, @dns_timeout, @connect_timeout
          io.read_timeout = @read_timeout if @read_timeout
          io.write_timeout = @write_timeout if @write_timeout
          io.sync = false

          {% if !flag?(:without_openssl) %}
            io = do_connect_ssl(io)
          {% end %}

          @io = io
        end

        def do_connect_ssl(io)
          if tls = @tls
            tcp_socket = io
            begin
              io = OpenSSL::SSL::Socket::Client.new(tcp_socket, context: tls, sync_close: true, hostname: @host)
            rescue ex
              # don't leak the TCP socket when the SSL connection failed
              tcp_socket.close
              raise ex
            end
          end

          io
        end
      end

      # #### Actual Instrumentation Here. This way, if the above gets accepted into Crystal
      # #### core, we just need to delete everything above here and we are good to go.

      class HTTP::Client
        trace("do_connect") do
          OpenTelemetry.in_span("HTTP::Client Connect") do |span|
            span.client!
            io = previous_def
            span["net.peer.name"] = @host
            span["net.peer.port"] = @port

            io
          end.not_nil!
        end

        trace("do_connect_ssl") do
          OpenTelemetry.in_span("Negotiate SSL") do |_span|
            previous_def
          end.not_nil!
        end

        def_around_exec do |request|
          OpenTelemetry.in_span("HTTP::Client #{request.method}") do |span|
            span.client!
            span["http.host"] = self.host
            span["http.port"] = self.port
            span["http.method"] = request.method
            span["http.flavor"] = request.version.split("/").last
            span["http.scheme"] = request.scheme
            if content_length = request.content_length
              span["http.response_content_length"] = content_length
            end
            span["http.url"] = "#{request.scheme}://#{self.host}:#{self.port}#{request.resource}"
            span["guid"] = span.span_id.hexstring

            OpenTelemetry::Propagation::TraceContext.new(span.context).inject(request.headers).not_nil!

            response = yield request

            if response.is_a?(HTTP::Client::Response)
              span["http.status_code"] = response.status_code
              if response.success?
                # span.status.ok!
              else
                span.status.error!
                span["http.status_message"] = response.status_message.to_s
              end
            end

            response
          end
        end
      end
    end
  end
end
