require "../instrument"

# # OpenTelemetry::Instrumentation::CrystalHttpServer
#
# ### Instruments:
#   * HTTP::Server
#   * HTTP::Handler
#   * HTTP::RequestProcessor
#
# ### Reference: [https://crystal-lang.org/api/latest/HTTP/Server.html](https://crystal-lang.org/api/latest/HTTP/Server.html)
#
# The **HTTP::Server** implementation, provided in the Crystal standard library, is utilized by
# most Crystal web frameworks. It provides a simple HTTP 1.x compliant server that applications
# can use to receive requests and to issue responses.
#
# The OpenTelemetry instrumentation of **HTTP::Server** will generate traces for each request, from
# the start to the end of it's handling.
#
# ## Methods Affected
#
# * HTTP::Server#handle_client
# * HTTP::Handler#call_next
# * HTTP::RequestProcessor#process
struct OpenTelemetry::InstrumentationDocumentation::CrystalHttpServer
end

unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_HTTP_SERVER") do
  if_defined?(::HTTP::Server) do
    module OpenTelemetry::Instrumentation
      class CrystalHttpServer < OpenTelemetry::Instrumentation::Instrument
      end
    end

    if_version?(Crystal, :>=, "1.0.0") do
      module HTTP::Handler
        trace("call_next") do
          if next_handler = @next
            OpenTelemetry::Trace.current_trace.not_nil!.in_span("Invoke handler #{next_handler.class.name}") do |_handler_span|
              previous_def
            end
          else
            span = OpenTelemetry::Trace.current_span
            span["http.status_code"] = HTTP::Status::NOT_FOUND.value if span
            previous_def
          end
        end
      end

      class HTTP::Request
        def full_url
          local_addr = local_address
          port = if local_addr && local_addr.is_a?(Socket::IPAddress)
                   ":#{local_addr.port}"
                 else
                   ""
                 end
          "#{scheme}://#{hostname}#{port}#{resource}"
        end

        def scheme
          if u = uri
            u.scheme.to_s.empty? ? version.split("/").first.downcase : u.scheme.to_s.downcase
          else
            ""
          end
        end
      end

      class HTTP::Server
        # This should actually work back to Crystal 0.18.0, but the rest of this code probably won't,
        # so I am arbitrarily setting the bottom limit at Crystal 1.0.0. It may work on the 0.3x
        # versions, but this is entirely untested.
        # Wrap the start of request handling, the call to handle_client, in top-level-instrumentation.
        trace("handle_client") do
          trace = OpenTelemetry.trace
          trace.in_span("HTTP::Server connection") do |span|
            span.server!
            remote_addr = io.as(TCPSocket).remote_address
            span["net.peer.ip"] = remote_addr.address
            span["net.peer.port"] = remote_addr.port
            # Without parsing the request, we do not yet know the hostname, so the span will be started
            # with what is known, the IP, and the actual hostname can be backfilled later, after it is
            # parsed.
            if (local_addr = io.as(TCPSocket).local_address) && io.as(TCPSocket).local_address.is_a?(Socket::IPAddress)
              span["net.peer.ip"] = local_addr.address
              span["net.peer.port"] = local_addr.port
            end
            span["http.host"] = local_addr.address
          end
          previous_def
        end

        # If the RequestProcessor were refactored a little bit, this could be much cleaner.
        class RequestProcessor
          # ameba:disable Metrics/CyclomaticComplexity
          def process(input, output)
            response = Response.new(output)

            begin
              until @wants_close
                request = HTTP::Request.from_io(
                  input,
                  max_request_line_size: max_request_line_size,
                  max_headers_size: max_headers_size,
                )

                break unless request
                trace = OpenTelemetry.trace
                trace_name = request.is_a?(HTTP::Request) ? "#{request.method} #{request.path}" : "ERROR #{request.code}"
                trace.in_span(trace_name) do |span|
                  span.server!
                  # TODO: When Span Links are supported, add a Link to the span that instrumented the actual connection.
                  response.reset

                  if request.is_a?(HTTP::Status)
                    if span
                      span["http.status_code"] = request.code
                      span.add_event("Malformed Request or Error") do |event|
                        event["http.status_code"] = request.code
                      end
                      span.status.error!("Malformed Request or Error: #{request.code} -> #{request.description}")
                    end
                    response.respond_with_status(request)
                    return
                  end

                  response.version = request.version
                  response.headers["Connection"] = "keep-alive" if request.keep_alive?
                  context = Context.new(request, response)

                  if span
                    span["http.host"] = request.hostname.to_s
                    span["http.method"] = request.method
                    span["http.flavor"] = request.version.split("/").last
                    span["http.scheme"] = request.scheme
                    if content_length = request.content_length
                      span["http.response_content_length"] = content_length
                    end
                    span["http.url"] = request.full_url
                  end

                  OpenTelemetry::Trace.current_trace.not_nil!.in_span("Invoke handler #{@handler.class.name}") do |handler_span|
                    Log.with_context do
                      @handler.call(context)
                    rescue ex : ClientError
                      Log.debug(exception: ex.cause) { ex.message }
                      handler_span.add_event("ClientError") do |event|
                        event["message"] = ex.message.to_s
                      end
                    rescue ex
                      Log.error(exception: ex) { "Unhandled exception on HTTP::Handler" }
                      handler_span.add_event("Unhandled exception on HTTP::Handler") do |event|
                        event["message"] = ex.message.to_s
                      end
                      unless response.closed?
                        unless response.wrote_headers?
                          span["http.status_code"] = HTTP::Status::INTERNAL_SERVER_ERROR.value if span
                          response.respond_with_status(:internal_server_error)
                        end
                      end
                      return
                    ensure
                      if response.status_code >= 400
                        span.status.error!("HTTP Error: #{response.status.code} -> #{response.status.description}")
                      end
                      response.output.close
                    end
                  end

                  output.flush

                  # If there is an upgrade handler, hand over
                  # the connection to it and return
                  if upgrade_handler = response.upgrade_handler
                    upgrade_handler.call(output)
                    return
                  end
                end
                break unless request
                break unless request.as(HTTP::Request).keep_alive?

                # Don't continue if the handler set `Connection` header to `close`
                break unless HTTP.keep_alive?(response)

                # The request body is either FixedLengthContent or ChunkedContent.
                # In case it has not entirely been consumed by the handler, the connection is
                # closed the connection even if keep alive was requested.
                case body = request.as(HTTP::Request).body
                when FixedLengthContent
                  if body.read_remaining > 0
                    # Close the connection if there are bytes remaining
                    break
                  end
                when ChunkedContent
                  # Close the connection if the IO has still bytes to read.
                  break unless body.closed?
                end
              end
            rescue IO::Error
              # IO-related error, nothing to do
            end
          end
        end
      end
    end
  end
end
