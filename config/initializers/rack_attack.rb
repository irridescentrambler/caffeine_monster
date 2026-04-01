# frozen_string_literal: true

module Rack
  # Implements rate limiting
  class Attack
    throttle('req/ip', limit: 100, period: 1.minute, &:ip)

    self.throttled_response = lambda do |_env|
      [429, { 'Content-Type' => 'application/json' }, [
        { error: 'Too many requests' }.to_json
      ]]
    end
  end
end
