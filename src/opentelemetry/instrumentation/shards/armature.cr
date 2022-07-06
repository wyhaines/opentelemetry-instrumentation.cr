require "../instrument"

# # OpenTelemetry::Instrumentation::Armature
#
# ### Instruments
#
#   * First::Class::Instrumented
#   * Second::Class::Instrumented
#
# ### Reference: [https://github.com/jgaskins/armature](https://github.com/jgaskins/armature)
#
# Description of the instrumentation provided, including any nuances, caveats, instructions, or warnings.
#
# ## Configuration
#
# - `OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_ARMATURE`
#
#   If set, this will **disable** the instrumentation.
#
# ## Version Restrictions
#
# * Crystal >= 1.0.0
#
# ## Methods Affected
#
# - `First::Class#method_name`
#
#   Description of instrumentation.
#
# - `First::Class#another_method_name`
#
#   Description of instrumentation.
#
# - `Second::Class#method_name`
#
#   Description of instrumentation.
#
# - `Second::Class#another_method_name`
#
#   Description of instrumentation.
#
struct OpenTelemetry::InstrumentationDocumentation::Armature
  # This provides a shelf where the documentation builder can place the documentation, since
  # the code for the instrumentation itself is conditionally compiled, and will therefore
  # likely never be parsed by the documentation builder.
end

# This allows opt-out of specific instrumentation at compile time, via environment variables.
# Refer to https://wyhaines.github.io/defined.cr/ for details about all supported check types.
unless_disabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_ARMATURE") do
  # Next should be one or more checks intended to validate that the class(es) to be instrumented
  # actually exist. It should be possible to require all instrumentation, regardless of whether
  # a given class/package is actually used, as the instrumentation should not attempt to install
  # itself if that installation will fail.
  if_defined?(Important::Class) do
    # This exists to record the instrumentation in the OpenTelemetry::Instrumentation::Registry,
    # which may be used by other code/tools to introspect the installed instrumentation.
    module OpenTelemetry::Instrumentation
      class Armature < OpenTelemetry::Instrumentation::Instrument
      end
    end

    # One or more version checks are useful, to ensure that the instrument will successfully
    # install itself if the required dependencies are present. One can also use this to provide
    # backwards compatible instrumentation, if changes make an older approach obsolete on newer
    # versions of the package.
    if_version?(Crystal, :>=, "1.0.0") do
      # Do instrumentation, leveraging `trace` where possible to easily wrap methods in
      # instrumentation, and traditional monkeypatching where this is not possible. The approach
      # may change if Crystal ever supports a Ruby-like `prepend`.
    end
  end
end
