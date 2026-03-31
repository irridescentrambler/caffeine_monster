# frozen_string_literal: true

# Validates email and password and returns a JWT when credentials match.
class AuthenticateUserService < BaseService
  attr_reader :email, :password

  def initialize(email, password)
    @email = email
    @password = password
    super()
  end

  def call
    user = User.find_by(email: email)
    if user&.authenticate(password)
      payload = { user_id: user.id }
      token = JsonWebToken.encode(payload)
      Response.new(token)
    else
      Response.new(nil, :unauthorized)
    end
  end
end
