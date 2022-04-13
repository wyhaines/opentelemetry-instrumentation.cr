require "colorize"

class ActionController
  VERSION = "4.7.3"

  class Context
  end

  class Router::RouteHandler
    def call(context)
      process_request("Home::Index", context, nil, false)
    end

    def process_request(search_path, context, controller_dispatch, head_request)
      :called
    end
  end
end
