# frozen_string_literal: true

# Deals of creation of JWT tokens for API authentication
class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create]
  skip_before_action :authorize_request, only: [:create]

  def create
    response = AuthenticateUserService.call(params[:email], params[:password])
    if response.success?
      render json: { token: response.data }
    else
      render json: { error: 'Unable to authenticate' }, status: response.error
    end
  end
end
