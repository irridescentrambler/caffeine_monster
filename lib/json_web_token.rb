# frozen_string_literal: true

# Encodes and decodes JWTs using the application auth secret; decode returns nil on error or expiry.
class JsonWebToken
  SECRET = Rails.application.credentials.auth_secret_key

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET)
  end

  def self.decode(token)
    JWT.decode(token, SECRET)[0].with_indifferent_access
  rescue JWT::ExpiredSignature, JWT::DecodeError
    nil
  end
end
