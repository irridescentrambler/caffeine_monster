# frozen_string_literal: true

# Deals with authorization of all the controller endpoints
module Authorize
  extend ActiveSupport::Concern

  included do
    before_action :authorize_request
  end

  def authorize_request
    return if request.format.html?

    response = AuthorizeUserService.call(request.headers)
    if response.success?
      @current_user = response.data[:user]
    else
      render json: { error: 'Unauthorized' }, status: response.error
    end
  end
end
