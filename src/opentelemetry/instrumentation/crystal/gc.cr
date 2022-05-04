require "../instrument"

# TODO: This may not be possible....
#
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
# * 
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
    end
  end
end
