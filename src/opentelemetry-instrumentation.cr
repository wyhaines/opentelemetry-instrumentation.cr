require "defined"
require "opentelemetry-sdk"
require "tracer"
require "./ext/*"
require "./opentelemetry-instrumentation/log_backend"

# There is a puzzle here. Ideally, this require is executed from a `finished` block.
# However, it is possible, and even likely that such a block, right here, will never be executed.
# The reason is that if code execution starts in a place that is ahead of where that block ends
# up being injected into the final code, then execution may _never_ reach the code that is
# required in said block.
# The onus will be on the user of the instrumentation to ensure that the instrumentation is
# required last, after all other code.
require "./opentelemetry/instrumentation/**"
