require "socket"

class TCPSocket
  getter hostname : String = ""

  # Preserve a hostname, if one is given. Nothing downstream preserves it, and it doesn't
  # make sense to lose that information. Many of the semantic conventions for various types
  # of spans really want to have this information.
  def initialize(host, port, dns_timeout = nil, connect_timeout = nil, blocking = false)
    @hostname = URI::Punycode.decode(host)
    previous_def
  end
end