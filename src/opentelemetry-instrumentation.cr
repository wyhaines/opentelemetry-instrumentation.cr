require "opentelemetry-api"
require "./ext/*"

macro finished
  require "./opentelemetry/instrumentation/**"
end
