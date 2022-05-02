require "../instrument"

# # OpenTelemetry::Instrumentation::CrystalGC
#
# ### Instruments
#   * GC
#
# ### Reference: [https://path.to/package_documentation.html](https://path.to/package_documentation.html)
#
# Description of the instrumentation provided, including any nuances, caveats, instructions, or warnings.
#
# ## Methods Affected
#
# * GC.collect
#
struct OpenTelemetry::InstrumentationDocumentation::CrystalGC
end

unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_GC") do
  # Next should be one or more checks intended to validate that the class(es) to be instrumented
  # actually exist. It should be possible to require all instrumentation, regardless of whether
  # a given class/package is actually used, as the instrumentation should not attempt to install
  # itself if that installation will fail.

  module OpenTelemetry::Instrumentation
    class InstrumentName < OpenTelemetry::Instrumentation::Instrument
    end
  end

  if_version?(Crystal, :>=, "1.0.0") do
    module GC
      def self.collect
        OpenTelemetry.trace.in_span("GC.collect") do |span|
          stats = GC.stats
          span["GC.bytes_since_gc"] = stats.bytes_since_gc
          span["GC.free_bytes"] = stats.free_bytes
          span["GC.heap_size"] = stats.heap_size
          span["GC.total_bytes"] = stats.total_bytes
          span["GC.unmapped_bytes"] = stats.unmapped_bytes
          previous_def
        end
      end
    end
  end
end
