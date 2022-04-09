require "spec"
require "../src/opentelemetry-instrumentation"

class FindJson
  @buffer : String = ""

  def initialize(@buffer)
  end

  def pull_json(buf)
    @buffer = @buffer + buf

    pull_json
  end

  def pull_json
    return nil if @buffer.empty?

    pos = 0
    start_pos = -1
    lefts = 0
    rights = 0
    while pos < @buffer.size
      if @buffer[pos] == '{'
        lefts = lefts + 1
        start_pos = pos if start_pos == -1
      end
      if @buffer[pos] == '}'
        rights = rights + 1
      end
      break if lefts > 0 && lefts == rights

      pos += 1
    end

    json = @buffer[start_pos..pos]
    @buffer = @buffer[pos + 1..-1]

    json
  end
end

# This helper macro can be used to selectively run only specific specs by turning on their
# focus in response to an environment variable.
macro it_may_focus_and_it(description, tags = "", &block)
{% if env("SPEC_ENABLE_FOCUS") %}
it {{ description.stringify }}, tags: {{ tags }}, focus: true do
  {{ block.body }}
end
{% else %}
it {{ description.stringify }}, tags: {{ tags }} do
  {{ block.body }}
end
{% end %}
end
