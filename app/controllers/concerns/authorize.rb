# frozen_string_literal: true

# Deals with authorization of all the controller endpoints
module Authorize
  extend ActiveSupport::Concern

  included do
    before_action :authorize_request
    helper_method :current_user
  end

  def current_user
    @current_user
  end

  def authorize_request
    if request.format.html?
      check_user_and_redirect
    else
      response = AuthorizeUserService.call(request.headers)
      if response.success?
        @current_user = response.data[:user]
      else
        render json: { error: 'Unauthorized' }, status: response.error
      end
    end
  end

  private

  def check_user_and_redirect
    user = User.find_by(id: session[:user_id])
    if user
      @current_user = user
    else
      redirect_to login_path, alert: 'Please log in to continue.'
    end
  end
end
