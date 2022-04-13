require "../instrument"

# # OpenTelemetry::Instrumentation::FrameWork::SpiderGazelle
#
# ### Instruments
#   * ActionController::Router::RouteHandler
#
# ### Reference: [action-controller/router/route_handler.cr](https://github.com/spider-gazelle/action-controller/blob/master/src/action-controller/router/route_handler.cr)
#
# Autoinstrumentation for Spider-Gazelle is pretty minimal. Other core instrumentation handles most of
# the heavy lifting. This instrumentation package supplements that work by adding the *http.route*
# attribute to the RouteHandler span, if there is a route to be added.
#
# To instrument a Spider-Gazelle application, add the following requires to your *src/config.cr* file:
#
# ```
# require "action-controller"
# require "opentelemetry-instrumentation"
# require "opentelemetry-instrumentation/src/opentelemetry/instrumentation/**"
# ```
#
# After adding that, add a stanza to do some basic configuration of the OpenTelemetry framework:
#
# ```
# OpenTelemetry.configure do |config|
#   config.service_name = "My Spider-Gazelle App"
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
# * ActionController::Router::RouteHandler#process_request
#
struct OpenTelemetry::InstrumentationDocumentation::Framework::SpiderGazelle
end

# This allows opt-out of specific instrumentation at compile time, via environment variables.
# Refer to https://wyhaines.github.io/defined.cr/ for details about all supported check types.
unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_FRAMEWORK_SPIDER_GAZELLE") do
  if_defined?(ActionController::Router::RouteHandler) do
    if_version?(ActionController, :>=, "4.7.3") do
      module OpenTelemetry::Instrumentation::Framework
        class SpiderGazelle < OpenTelemetry::Instrumentation::Instrument
        end
      end

      # the process_request function is designed for OpenTelemetry tracing
      class ActionController::Router::RouteHandler
        trace("process_request") do
          span = OpenTelemetry::Trace.current_span
          if span
            span["http.route"] = search_path
          end

          previous_def
        end
      end
    end
  end
end
