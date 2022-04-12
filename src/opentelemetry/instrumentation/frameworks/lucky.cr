require "../instrument"

# # OpenTelemetry::Instrumentation::FrameWork::Lucky
#
# ### Instruments
#   * Lucky::RouteHandler
#
# ### Reference: [https://luckyframework.github.io/lucky/Lucky/RouteHandler.html](https://luckyframework.github.io/lucky/Lucky/RouteHandler.html)
#
# Autoinstrumentation for Lucky is pretty minimal. Other core instrumentation handles most of
# the heavy lifting. This instrumentation package supplements that work my adding the *http.route*
# attribute to the RouteHandler span, if there is a route to be added.
#
# To instrument a Lucky application, add the following requires to your *src/start_server.cr* file:
#
# ```
# require "opentelemetry-instrumentation"
# require "opentelemetry-instrumentation/src/opentelemetry/instrumentation/**"
# ```
#
# After adding that, add a stanza to do some basic configuration of the OpenTelemetry framework:
#
# ```
# OpenTelemetry.configure do |config|
#   config.service_name = "My Lucky App"
#   config.service_version = "1.0.0"
#   config.exporter = OpenTelemetry::Exporter.new(variant: :http) do |exporter|
#     exporter = exporter.as(OpenTelemetry::Exporter::Http)
#     exporter.endpoint = "https://otlp.nr-data.net:4318/v1/traces"
#     headers = HTTP::Headers.new
#     headers["api-key"] = ENV["NEW_RELIC_LICENSE_KEY"]?.to_s
#     exporter.headers = headers
#   end
# end
# ```
#
# That is all that you should need to do. If your environment has an appropriate license key
# in the *NEW_RELIC_LICENSE_KEY* environment variable, the OpenTelemetry exporter will send
# the traces to New Relic. A similar setup should work with any provider that supports OTLP/HTTP
# ingest of OpenTelemetry.
#
# ## Methods Affected
#
# * Lucky::RouteHandler#call
#
struct OpenTelemetry::InstrumentationDocumentation::Framework::Lucky
end

# This allows opt-out of specific instrumentation at compile time, via environment variables.
# Refer to https://wyhaines.github.io/defined.cr/ for details about all supported check types.
unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_FRAMEWORK_LUCKY") do
  if_defined?(Lucky::RouteHandler) do
    if_version?(Lucky, :>=, "0.29.0") do
      module OpenTelemetry::Instrumentation::Framework
        class Lucky < OpenTelemetry::Instrumentation::Instrument
        end
      end

      # There are two options here. The other is to monkeypath Lucky::RouteHandler#call
      # directly, and inject code in it to create the span. This seems less invasive, and
      # less fragile, but will be a bit slower since the find_action gets called twice.
      class Lucky::RouteHandler
        trace("call") do
          span = OpenTelemetry::Trace.current_span
          if span
            handler = Lucky.router.find_action(context.request)
            if handler
              span["http.route"] = handler.payload.to_s
            end
          end

          previous_def
        end
      end
    end
  end
end
