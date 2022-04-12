require "colorize"

class Lucky
  VERSION = "0.30.0"

  class Context
    def request
      "any old junk"
    end
  end

  class Handler
    def payload
      "Home::Index"
    end
  end

  class Router
    def find_action(context)
      Handler.new
    end
  end

  def self.router
    Router.new
  end
end

class Lucky::RouteHandler
  def call(context)
    :called
  end
end
