# Roadmap

This document represents a general set of goals for the project. It will change over time, and should be taken as a document that presents a general vision and plan for what is to come, and not as a document with specific tasks or milestones expressed. All specific goals and tasks will be found [as issues](https://github.com/wyhaines/opentelemetry-instrumentation.cr/issues).

- Improve Documentation

  Ensure that all of the instruments are fully documented, with a consistent documentation format.

- Configuration File Support

  Right now, all configuration happens only through environment variable. Environment variable based configuration is essential, but projects want to carry their standard configuration in files. The auto-instrumentation should support a standard configuration file that can be used to tweak the behavior of both the individual instruments, and the overall OpenTelemetry behavior as a whole. While this configuration support is listed as going into the instrumentation library, the instrumentation format that is chosen must also support other uses, such as specifying basic configuration, exporter(s) to use and their configuration, sampling configuration, span processor configuration, etc.

- Add more instruments

  ORM specific instruments, such as for Avram and Jennifer, should be added. Support for software like Mosquito and Sidekiq should be added. There should also be support for other HTTP client libraries like crest. This is a very long term roadmap item.