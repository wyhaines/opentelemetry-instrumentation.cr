require "../instrument"

#
# # OpenTelemetry::Instrumentation::CrystalGC
#
# ### Instruments
#
#   * GC
#
# ### Reference: [https://crystal-lang.org/api/1.4.1/GC.html](https://crystal-lang.org/api/1.4.1/GC.html)
#
# To instrument garbage collection, the ideal world would be to have something that could record a timestamp
# before the GC cycle runs, and then trigger an action after it completes which would create a span, using the
# prerecorded GC start timestamp.
#
# Right now I know of no way to do this. So the next best option is what we have implemented here. This
# instrument creates a fiber that spends most of its life sleeping. One a regular interval, which defaults to
# 300 seconds, it will wake, gather current GC stats, and create a span to record those. If there is a currently
# active trace, the span will be injected into that trace. Otherwise, it will be a standalone trace.
#
# TODO: If the API adds a mechanism for creating what is essentially a trace future, this will be changed so that
# it can, based on a config setting, use that. This will let people choose to have GC spans _always_ exist only
# in their own traces, which is probably what makes the most sense in a world where we can't hook directly into
# the GC cycle.
#
# ## Configuration
#
# - `OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_GC`
#
#   If set, this will **disable** the garbage collection instrumentation.
#
# - `OTEL_CRYSTAL_GC_SIMPLE_STATS`
#
#   If set, then this instrument returns a smaller, simpler set of garbage collection statistics.
#
#   - Simple Stats:
#
#     - gc.bytes_since_gc
#     - gc.free_bytes
#     - gc.heap_size
#     - gc.total_bytes
#     - gc.unmapped_bytes
#
#   - Full Stats:
#
#     - gc.bytes_before_gc
#     - gc.bytes_reclaimed_since_gc
#     - gc.bytes_since_gc
#     - gc.free_bytes
#     - gc.gc_no
#     - gc.heap_size
#     - gc.markers_m1
#     - gc.non_gc_bytes
#     - gc.reclaimed_bytes_before_gc
#     - gc.unmapped_bytes
#
# - `OTEL_CRYSTAL_GC_SPAN_RECORDING_INTERVAL`
#
#   If set, this is expected to be a positive integer which specifies the number of seconds in between reporting
#   intervals for GC stats. If not set, defaults to 300 seconds.
#
# ## Version Restrictions
#
# * Crystal >= 1.0.0
#
# ## Methods Affected
#
# - NONE
#
struct OpenTelemetry::InstrumentationDocumentation::CrystalGC
end

unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_GC") do
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
        OpenTelemetry.trace.in_span("GC Stats") do |span|
          if ENV["OTEL_CRYSTAL_GC_SIMPLE_STATS"]?
            stats = GC.stats
            span["gc.bytes_since_gc"] = stats.bytes_since_gc
            span["gc.free_bytes"] = stats.free_bytes
            span["gc.heap_size"] = stats.heap_size
            span["gc.total_bytes"] = stats.total_bytes
            span["gc.unmapped_bytes"] = stats.unmapped_bytes
          else
            stats = GC.prof_stats
            span["gc.bytes_before_gc"] = stats.bytes_before_gc
            span["gc.bytes_reclaimed_since_gc"] = stats.bytes_reclaimed_since_gc
            span["gc.bytes_since_gc"] = stats.bytes_since_gc
            span["gc.free_bytes"] = stats.free_bytes
            span["gc.gc_no"] = stats.gc_no
            span["gc.heap_size"] = stats.heap_size
            span["gc.markers_m1"] = stats.markers_m1
            span["gc.non_gc_bytes"] = stats.non_gc_bytes
            span["gc.reclaimed_bytes_before_gc"] = stats.reclaimed_bytes_before_gc
            span["gc.unmapped_bytes"] = stats.unmapped_bytes
          end
        end

        sleep ENV["OTEL_CRYSTAL_GC_SPAN_RECORDING_INTERVAL"]?.try(&.to_i?) ? ENV["OTEL_CRYSTAL_GC_SPAN_RECORDING_INTERVAL"].to_i : 300
      end
    end
  end
end
