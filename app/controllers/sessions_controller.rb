# frozen_string_literal: true

# Handles session creation (web login/logout) and JWT token creation for API authentication
class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create]
  skip_before_action :authorize_request, only: %i[new create]

  def new; end

  def create
    @user = User.find_by(email: params[:email])
    if @user&.authenticate(params[:password])
      handle_successful_login
    else
      handle_error
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: 'Logged out successfully.'
  end

  private

  def handle_successful_login
    respond_to do |format|
      format.html do
        session[:user_id] = @user.id
        redirect_to users_path, notice: 'Logged in successfully.'
      end
      format.json do
        token = JsonWebToken.encode({ user_id: @user.id })
        render json: { token: token }
      end
    end
  end

  def handle_error
    respond_to do |format|
      format.html do
        flash.now[:alert] = 'Invalid email or password.'
        render :new, status: :unprocessable_entity
      end
      format.json { render json: { error: 'Unable to authenticate' }, status: :unauthorized }
    end
  end
end
