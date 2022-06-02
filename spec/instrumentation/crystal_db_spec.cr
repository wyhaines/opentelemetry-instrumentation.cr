require "../spec_helper"
require "sqlite3"

SetupIOAndOtel = ->do
  memory = IO::Memory.new
  OpenTelemetry.configure do |config|
    config.service_name = "Crystal OTel Instrumentation - DB::Statement"
    config.service_version = "1.0.0"
    config.exporter = OpenTelemetry::Exporter.new(variant: :io, io: memory)
  end

  memory
end

SetupDB = ->do
  DB.open "sqlite3://./data.db" do |db|
    db.exec "create table contacts (name text, age integer, timestamp time)"
    db.exec "insert into contacts values (?, ?, ?)", "John Doe", 30, Time.local

    args = [] of DB::Any
    args << "Sarah"
    args << 33
    args << Time.utc
    db.exec "insert into contacts values (?, ?, ?)", args: args
    db.scalar "select max(age) from contacts" # => 33
    db.query "select name, age, timestamp from contacts order by age desc" do |rs|
      rs.each do
        "#{rs.read(String)} (#{rs.read(Int32)})"
      end
    end
  end
end

ExtractTraces = ->(memory : IO::Memory) do
  memory.rewind
  strings = memory.gets_to_end
  json_finder = FindJson.new(strings)

  traces = [] of JSON::Any
  while json = json_finder.pull_json
    traces << JSON.parse(json)
  end

  traces
end

describe DB::Statement, tags: "DB::Statement" do
  before_each do
    if File.exists?("data.db")
      File.delete("data.db")
    end
  end

  after_each do
    if File.exists?("data.db")
      File.delete("data.db")
    end
  end

  it "will create traces and spans for db activity even if there is no top level span" do
    memory = SetupIOAndOtel.call
    pp OpenTelemetry.config
    SetupDB.call
    traces = ExtractTraces.call(memory)

    traces.size.should eq 5
    traces[0]["resource"]["service.name"].should eq "Crystal OTel Instrumentation - DB::Statement"
    traces[0]["spans"][0]["kind"].should eq 3
    traces[0]["spans"][0]["name"].should eq "data.db->CREATE"
    traces[0]["spans"][0]["attributes"]["db.name"].should eq "data.db"
    traces[4]["spans"][0]["attributes"]["db.statement"].should eq "select name, age, timestamp from contacts order by age desc"
  end

  it "will create multiple spans for db activity under an existing trace" do
    memory = SetupIOAndOtel.call

    OpenTelemetry.trace.in_span("Do a bunch of DB Queries") do
      SetupDB.call
    end

    traces = ExtractTraces.call(memory)
    traces.size.should eq 1
    traces[0]["resource"]["service.name"].should eq "Crystal OTel Instrumentation - DB::Statement"
    traces[0]["spans"][0]["kind"].should eq 1
    traces[0]["spans"][0]["name"].should eq "Do a bunch of DB Queries"
    parent_span_id = traces[0]["spans"][0]["spanId"]
    traces[0]["spans"][1]["kind"].should eq 3
    traces[0]["spans"][1]["name"].should eq "data.db->CREATE"
    traces[0]["spans"][1]["attributes"]["db.name"].should eq "data.db"
    traces[0]["spans"][1]["parentSpanId"].should eq parent_span_id
    traces[0]["spans"][5]["attributes"]["db.statement"].should eq "select name, age, timestamp from contacts order by age desc"
  end
end
