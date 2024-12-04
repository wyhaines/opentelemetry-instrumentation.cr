require "../spec_helper"

# This spec just tests the null case....an instrument that does not exist should, in fact,
# not exist.
describe "instrumentation on Int32, which should never exist" do
  it "has no false positives for instrumentation that just should not ever exist" do
    Tracer::TRACED_METHODS_BY_RECEIVER[Int32]?.should be_nil
  end
end
