require "./instrument"

module OpenTelemetry
  module Instrumentation
    class Registry
      @@name_to_class_map = {} of String => OpenTelemetry::Instrumentation::Instrument.class
      @@lock = Mutex.new

      def self.[]=(name, klass)
        @@lock.synchronize do
          @@name_to_class_map[name] = klass
        end
      end

      def self.set(name, klass)
        self[name] = klass
      end

      def self.register(klass)
        @@lock.synchronize do
          @@name_to_class_map[klass.instrument_name.downcase] = klass
        end
      end

      def self.registry
        @name_to_class_map
      end

      def self.[](key)
        get(key)
      end

      def self.get(key)
        @@name_to_class_map[key]
      end

      def self.instrument_names
        @@name_to_class_map.keys
      end

      def self.instruments
        @@name_to_class_map.values
      end
    end
  end
end
