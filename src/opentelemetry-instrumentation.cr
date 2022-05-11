require "defined"
require "opentelemetry-api"
require "tracer"
require "./ext/*"
require "./opentelemetry-instrumentation/log_backend"

macro finished
  require "./opentelemetry/instrumentation/**"
end
