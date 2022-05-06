require "../instrument"

# # OpenTelemetry::Instrumentation::CrystalHttpWebSocket
#
# ### Instruments
#   * HTTP::WebSocket
#
# ### Reference: [https://crystal-lang.org/api/1.4.0/HTTP/WebSocket.html](https://crystal-lang.org/api/1.4.0/HTTP/WebSocket.html)
#
# This instrumentation package instruments both client and server use of HTTP::WebSocket. As of 0.3.0 of
# of `OpenTelemetry::Instrumentation`, the package first monkey patches HTTP::WebSocket to rewrite it into a
# refactored version that reduces the [cyclomatic complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity)
# of the `#run` method while also making it easier to inject tracing. Those refactors are being presented back
# to the main Crystal project as a proposed PR, and if they are accepted, a large chunk of the code in this
# instrumentation package can be removed.
#
# The remaining instrumentation wraps the client methods, `#send`, `#ping`, `#pong`, `#stream`, and `#close`,
# as well as the refactored handler methods that `#run` depends on, `#handle_ping`, `#handle_pong`, `#handle_text`,
# `#handle_binary`, `#handle_close`, and `#handle_continuation`.
#
# ## Methods Affected
#
# * HTTP::WebSocket#run
# * HTTP::WebSocket#send
# * HTTP::WebSocket#ping
# * HTTP::WebSocket#pong
# * HTTP::WebSocket#stream
# * HTTP::WebSocket#close
# * HTTP::WebSocket#handle_ping
# * HTTP::WebSocket#handle_pong
# * HTTP::WebSocket#handle_text
# * HTTP::WebSocket#handle_binary
# * HTTP::WebSocket#handle_close
# * HTTP::WebSocket#handle_continuation
#
struct OpenTelemetry::InstrumentationDocumentation::CrystalHttpWebSocket
end

unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_HTTP_WEBSOCKET") do
  if_defined?(::HTTP::WebSocket) do
    # This exists to record the instrumentation in the OpenTelemetry::Instrumentation::Registry,
    # which may be used by other code/tools to introspect the installed instrumentation.
    # :nodoc:
    module OpenTelemetry::Instrumentation
      class CrystalHttpWebSocket < OpenTelemetry::Instrumentation::Instrument
      end
    end

    if_version?(Crystal, :>=, "1.0.0") do
      # This redefinition of part of the class is being submitted as a PR to Crystal. If it is accepted,
      # then this big monkeypatch can be removed, leaving only the instrumentation that follows it.
      class HTTP::WebSocket
        @[AlwaysInline]
        private def buffer_slice(info)
          @buffer[0, info.size]
        end

        @[AlwaysInline]
        private def handle_ping(info)
          @current_message.write @buffer[0, info.size]
          if info.final
            message = @current_message.to_s
            @on_ping.try &.call(message)
            pong(message) unless closed?
            @current_message.clear
          end
        end

        @[AlwaysInline]
        private def handle_pong(info)
          @current_message.write @buffer[0, info.size]
          if info.final
            @on_pong.try &.call(@current_message.to_s)
            @current_message.clear
          end
        end

        @[AlwaysInline]
        private def handle_text(info)
          @current_message.write buffer_slice(info)
          if info.final
            @on_message.try &.call(@current_message.to_s)
            @current_message.clear
          end
        end

        @[AlwaysInline]
        private def handle_binary(info)
          @current_message.write @buffer[0, info.size]
          if info.final
            @on_binary.try &.call(@current_message.to_slice)
            @current_message.clear
          end
        end

        @[AlwaysInline]
        private def handle_close(info)
          @current_message.write @buffer[0, info.size]
          if info.final
            @current_message.rewind

            if @current_message.size >= 2
              code = @current_message.read_bytes(UInt16, IO::ByteFormat::NetworkEndian).to_i
              code = CloseCode.new(code)
            else
              code = CloseCode::NoStatusReceived
            end
            message = @current_message.gets_to_end

            @on_close.try &.call(code, message)
            close

            @current_message.clear
            true
          end
        end

        @[AlwaysInline]
        private def handle_continuation(info)
          # TODO: (asterite) I think this is good, but this case wasn't originally handled
        end

        def run : Nil
          loop do
            begin
              info = @ws.receive(@buffer)
            rescue
              @on_close.try &.call(CloseCode::AbnormalClosure, "")
              @closed = true
              break
            end

            case info.opcode
            when .ping?
              handle_ping(info)
            when .pong?
              handle_pong(info)
            when .text?
              handle_text(info)
            when .binary?
              handle_binary(info)
            when .close?
              break if handle_close(info)
            when Protocol::Opcode::CONTINUATION
              handle_continuation(info)
            end
          end
        end
      end

      class HTTP::WebSocket
        trace("send") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket do send") do |span|
            span.client!
            span["message"] = message.to_s
            previous_def
          end
        end

        trace("ping") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket do ping") do |span|
            span.client!
            span["message"] = message.to_s
            previous_def
          end
        end

        trace("pong") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket do pong") do |span|
            span.client!
            span["message"] = message.to_s
            previous_def
          end
        end

        trace("stream") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket do stream") do |span|
            span.client!
            if binary
              span["message"] = "[BINARY DATA]" # TODO: should this dump binary data as hexstrings? Or make that something that can be turned on if desired?
            else
              span["message"] = message.to_s
            end
            previous_def
          end
        end

        trace("close") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket do close") do |span|
            span.client!
            span["close_code"] = close_code.to_s
            span["message"] = message.to_s
            previous_def
          end
        end

        trace("handle_ping") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket handle ping") do |span|
            span.server!
            span["message"] = String.new(buffer_slice(info))
            previous_def
          end
        end

        trace("handle_pong") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket handle pong") do |span|
            span.server!
            span["message"] = String.new(buffer_slice(info))
            previous_def
          end
        end

        trace("handle_text") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket handle text") do |span|
            span.server!
            span["message"] = String.new(buffer_slice(info))
            previous_def
          end
        end

        trace("handle_binary") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket handle binary") do |span|
            span.server!
            span["message"] = String.new(buffer_slice(info))
            previous_def
          end
        end

        trace("handle_close") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket handle close") do |span|
            span.server!
            span["message"] = String.new(buffer_slice(info))
            previous_def
          end
        end

        trace("handle_continuation") do
          OpenTelemetry.trace.in_span("HTTP::WebSocket handle continuation") do |span|
            span.server!
            previous_def
          end
        end
      end
    end
  end
end
