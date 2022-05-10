require "opentelemetry-api"
require "tracer"
require "./ext/*"
require "./opentelemetry-instrumentation/log_backend"

macro finished
  puts "DOING INSTRUMENTATION REQUIRES"
  require "./opentelemetry/instrumentation/**"
end
