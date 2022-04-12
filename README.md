![OpenTelemetry CI](https://img.shields.io/github/workflow/status/wyhaines/opentelemetry-instrumentation.cr/OpenTelemetry%20CI?style=for-the-badge&logo=GitHub)
[![GitHub release](https://img.shields.io/github/release/wyhaines/opentelemetry-instrumentation.cr.svg?style=for-the-badge)](https://github.com/wyhaines/opentelemetry-instrumentation.cr/releases)
![GitHub commits since latest release (by SemVer)](https://img.shields.io/github/commits-since/wyhaines/opentelemetry-instrumentation.cr/latest?style=for-the-badge)

# opentelemetry-instrumentation

This package provides both the base functionality needed to build instrumentation for arbitrary classes/libraries, but also ready-made instrumentation for commonly used Crystal libraries.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     opentelemetry-instrumentation:
       github: your-github-user/opentelemetry-instrumentation.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "opentelemetry-instrumentation.cr"
```

Requiring the top level library will attempt to instrument, via a `macro finished` block, every component within your project for which there exists instrumentation. Each instrumentation package attempts to determine whether it is safe to install before doing so, by validating that required components are installed, and that their versions are compatible.

The reason for running the autoinstrumentation within a `finished` block is to ensure that all other classes have been loaded prior to loading the instrumentation. However, the structure of some softare and frameworks (such as [https://luckyframework.org/](https://luckyframework.org/)) prevent this from working properly. If it appears that instrumentation has not been installed, you can check what instruments have been installed by examining the data returned from `OpenTelemetry::Instrumentation::Registry.instruments`. It may look like this:

```crystal
[OpenTelemetry::Instrumentation::CrystalDB,
OpenTelemetry::Instrumentation::CrystalHttpServer,
OpenTelemetry::Instrumentation::CrystalLog]

```

If the array is empty, then no instrumentation was installed. You can require instrumentation manually by requiring the relevant file. For instance, to manually install the DB instrumentation (assuming that DB has been previously required):

```crystal
require "opentelemetry-instrumentation/

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/wyhaines/opentelemetry-instrumentation.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Kirk Haines](https://github.com/wyhaines) - creator and maintainer

![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/wyhaines/opentelemetry-instrumentation.cr?style=for-the-badge)
![GitHub issues](https://img.shields.io/github/issues/wyhaines/opentelemetry-instrumentation.cr?style=for-the-badge)
