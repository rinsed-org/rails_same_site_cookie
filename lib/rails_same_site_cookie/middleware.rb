require 'rails_same_site_cookie/user_agent_checker'

module RailsSameSiteCookie
  class Middleware

    COOKIE_SEPARATOR = "\n".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      Rails.logger.debug('rails_same_site_cookie: call')
      status, headers, body = @app.call(env)

      regex = RailsSameSiteCookie.configuration.user_agent_regex
      set_cookie = headers['Set-Cookie']

      Rails.logger.debug('rails_same_site_cookie: before if block', status: status, headers: headers, body: body, regex: regex, set_cookie: set_cookie)
      if (regex.nil? or regex.match(env['HTTP_USER_AGENT'])) and not (set_cookie.nil? or set_cookie.strip == '')
        parser = UserAgentChecker.new(env['HTTP_USER_AGENT'])

        Rails.logger.debug('rails_same_site_cookie: checking parser', parser: parser, send_same_site_none: parser.send_same_site_none?)
        if parser.send_same_site_none?
          cookies = set_cookie.split(COOKIE_SEPARATOR)
          ssl = Rack::Request.new(env).ssl?

          Rails.logger.debug('rails_same_site_cookie: iterating through cookies', cookies: cookies, ssl: ssl, chrome: parser.chrome?)
          cookies.each do |cookie|
            next if cookie == '' or cookie.nil?
            next if !ssl && parser.chrome? # https://www.chromestatus.com/feature/5633521622188032

            if ssl and not cookie =~ /;\s*secure/i
              cookie << '; Secure'
            end

            unless cookie =~ /;\s*samesite=/i
              cookie << '; SameSite=None'
            end

          end

          headers['Set-Cookie'] = cookies.join(COOKIE_SEPARATOR)
        end
      end

      [status, headers, body]
    end

  end
end
