# frozen_string_literal: true

# Resolves the current user from a Bearer JWT in the request Authorization header.
class AuthorizeUserService < BaseService
  attr_reader :headers

  def initialize(headers)
    @headers = headers
    super
  end

  def call
    return Response.new(nil, :unauthorized) unless decoded_auth_token

    user = User.find_by(id: decoded_auth_token[:user_id])
    if user
      Response.new({ user: user }, nil)
    else
      Response.new(nil, :unauthorized)
    end
  end

  private

  def decoded_auth_token
    payload = JsonWebToken.decode(http_auth_token)
    return unless payload&.fetch(:user_id)

    payload
  end

  def http_auth_token
    auth_header = headers.fetch('HTTP_AUTHORIZATION') || headers.fetch('AUTHORIZATION') || ''
    scheme, token = auth_header.split(' ', 2)
    return unless scheme == 'Bearer'

    token
  end
end
