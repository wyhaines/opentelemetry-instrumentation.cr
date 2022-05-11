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
    # It doesn't appear easy/possible to hook into the GC in a way that lets us
    # record any stats in the moment before GC runs. If a means to do this can
    # be achieved, the code below will become more deterministic. For now, though,
    # the GC instrument will just be a fiber that wakes periodically to record a
    # span with the GC stats. If there is an existing trace, the span will be
    # inserted into it. If there is no currently active trace, the GC stats will
    # create a single-span trace.
    spawn(name: "GC Span Recording") do
      loop do
        stats = GC.prof_stats
        OpenTelemetry.trace.in_span("GC Stats") do |span|
          span["gc.bytes_before_gc"] = stats.bytes_before_gc
          span["gc.bytes_reclaimed_sinc_gc"] = stats.bytes_reclaimed_since_gc
          span["gc.bytes_since_gc"] = stats.bytes_since_gc
          span["gc.free_bytes"] = stats.free_bytes
          span["gc.gc_no"] = stats.gc_no
          span["gc.heap_size"] = stats.heap_size
          span["gc.markers_m1"] = stats.markers_m1
          span["gc.non_gc_bytes"] = stats.non_gc_bytes
          span["gc.reclaimed_bytes_before_gc"] = stats.reclaimed_bytes_before_gc
          span["gc.unmapped_bytes"] = stats.unmapped_bytes
        end
    
        sleep ENV["OTEL_CRYSTAL_GC_SPAN_RECORDING_INTERVAL"]?.try(&.to_i?) ? ENV["OTEL_CRYSTAL_GC_SPAN_RECORDING_INTERVAL"].to_i : 300 
      end
    end
  end
end
