require "../instrument"

# # OpenTelemetry::Instrumentation::Avram
#
# ### Instruments
#
#   * First::Class::Instrumented
#   * Second::Class::Instrumented
#
# ### Reference: [https://github.com/luckyframework/avram](https://path.to/package_documentation.html)
#
# Description of the instrumentation provided, including any nuances, caveats, instructions, or warnings.
#
# ## Configuration
#
# - `OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_AVRAM`
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
struct OpenTelemetry::InstrumentationDocumentation::Avram
  # This provides a shelf where the documentation builder can place the documentation, since
  # the code for the instrumentation itself is conditionally compiled, and will therefore
  # likely never be parsed by the documentation builder.
end

# This allows opt-out of specific instrumentation at compile time, via environment variables.
# Refer to https://wyhaines.github.io/defined.cr/ for details about all supported check types.
unless_disabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_AVRAM") do
  # Next should be one or more checks intended to validate that the class(es) to be instrumented
  # actually exist. It should be possible to require all instrumentation, regardless of whether
  # a given class/package is actually used, as the instrumentation should not attempt to install
  # itself if that installation will fail.
  if_defined?(Important::Class) do
    # This exists to record the instrumentation in the OpenTelemetry::Instrumentation::Registry,
    # which may be used by other code/tools to introspect the installed instrumentation.
    module OpenTelemetry::Instrumentation
      class Avram < OpenTelemetry::Instrumentation::Instrument
      end
    end

    # One or more version checks are useful, to ensure that the instrument will successfully
    # install itself if the required dependencies are present. One can also use this to provide
    # backwards compatible instrumentation, if changes make an older approach obsolete on newer
    # versions of the package.
    if_version?(Avram, :>=, "0.22.0") do
      module Avram::Queryable(T)
        def results
          OpenTelemetry.trace self.class.name do |span|
            # Largely copied from src/integrations/db.cr and tweaked for Avram
            assign_otel_attributes span, operation: "SELECT"

            result = previous_def
            span["db.row_count"] = result.size
            result
          end
        end

        def delete
          OpenTelemetry.trace "#{self.class.name}#delete" do |span|
            assign_otel_attributes span, operation: "DELETE"

            result = previous_def
            span["db.row_count"] = result
            result
          end
        end

        private def assign_otel_attributes(span, operation)
          span["net.transport"] = "ip_tcp"
          span["db.table"] = query.table.to_s
          span["db.system"] = "postgresql"
          sql = to_sql.join(", ")
          span["db.statement"] = sql
          span["db.operation"] = operation
          span.kind = :client

          # TODO: Is there a way to get these attributes in Avram?
          # span["db.connection_string"] = db_uri.to_s
          # span["db.user"] = db_uri.user
          # span["net.peer.name"] = db_uri.host
          # span["net.peer.port"] = db_uri.port
          # span["db.name"] = db_uri.path[1..]
        end
      end

      class Avram::SaveOperation(T)
        def save
          OpenTelemetry.trace "#{self.class.name}#save" do |span|
            previous_def
          end
        end
      end
    end
  end
end
