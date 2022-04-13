require "opentelemetry-api"
require "tracer"
require "./ext/*"

macro finished
  require "./opentelemetry/instrumentation/**"
end
