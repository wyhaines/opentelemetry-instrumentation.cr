require "./spec_helper"
require "./registry_spec/good_spec_instrument"
require "./registry_spec/bad_spec_instrument"

describe OpenTelemetry::Instrumentation::Registry do
  it "will register an included instrumentation class" do
    OpenTelemetry::Instrumentation::Registry.instruments.includes?(OpenTelemetry::Instrumentation::GoodSpecInstrument).should be_true
    OpenTelemetry::Instrumentation::Registry.instruments.includes?(OpenTelemetry::Instrumentation::BadSpecInstrument)
    OpenTelemetry::Instrumentation::Registry.instrument_names.includes?("goodspecinstrument").should be_true
    OpenTelemetry::Instrumentation::Registry.instrument_names.includes?("badspecinstrument").should be_true
  end

  it "can get a specific instrument class, by name" do
    OpenTelemetry::Instrumentation::Registry.get("goodspecinstrument").should eq OpenTelemetry::Instrumentation::GoodSpecInstrument
    OpenTelemetry::Instrumentation::Registry["badspecinstrument"].should eq OpenTelemetry::Instrumentation::BadSpecInstrument
  end

  it "can set an instrument class, by an alternate name" do
    OpenTelemetry::Instrumentation::Registry.set("bsi", OpenTelemetry::Instrumentation::BadSpecInstrument)
    OpenTelemetry::Instrumentation::Registry.get("bsi").should eq OpenTelemetry::Instrumentation::BadSpecInstrument
    OpenTelemetry::Instrumentation::Registry["gsi"] = OpenTelemetry::Instrumentation::GoodSpecInstrument
    OpenTelemetry::Instrumentation::Registry["gsi"].should eq OpenTelemetry::Instrumentation::GoodSpecInstrument
  end
end
