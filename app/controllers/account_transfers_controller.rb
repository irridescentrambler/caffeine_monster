# frozen_string_literal: true

# Handles money transfers out of an account.
#
# Transfers are JSON-only and delegate to MoneyTransferService, which wraps the
# atomic +transferAmount+ stored procedure. A user may only transfer out of the
# account they own.
class AccountTransfersController < ApplicationController
  # Error message the stored procedure raises when either account id is unknown.
  MISSING_ACCOUNT_MESSAGE = 'One or both accounts do not exist'
  # Error message MoneyTransferService returns for unexpected database failures.
  UNEXPECTED_ERROR_MESSAGE = 'Transfer failed. Please try again later.'
  # Error message rendered when +to_account_id+ or +amount+ is missing or non-numeric.
  INVALID_PARAMS_MESSAGE = 'to_account_id and amount are required and must be numeric'
  # Error message rendered when the account belongs to somebody else.
  FORBIDDEN_MESSAGE = 'You are not allowed to transfer from this account'

  skip_before_action :verify_authenticity_token, only: %i[create]
  before_action :load_account, only: %i[create]
  before_action :authorize_account_owner, only: %i[create]

  # POST /accounts/1/transfer.json
  #
  # Moves +amount+ from the account named in the path to +to_account_id+.
  #
  # Responds with one of:
  # - 200 — <tt>{ message: 'Transfer successful' }</tt>
  # - 401 — the request is not authenticated
  # - 403 — the account does not belong to the current user
  # - 404 — the source or destination account does not exist
  # - 422 — invalid params, non-positive amount, same-account transfer, or insufficient balance
  # - 500 — an unexpected database failure
  def create
    result = transfer_result

    respond_to do |format|
      format.json { render_transfer_result(result) }
    end
  end

  private

  # Runs the transfer, turning param coercion failures into a failed Response
  # so they render as 422 alongside the service's own validation errors.
  def transfer_result
    MoneyTransferService.call(@account.id, params[:to_account_id], params[:amount])
  rescue ArgumentError, TypeError
    BaseService::Response.new(nil, { message: INVALID_PARAMS_MESSAGE })
  end

  # Renders the service outcome, mapping failures onto an HTTP status.
  #
  # +result+ - the BaseService::Response returned by MoneyTransferService
  def render_transfer_result(result)
    return render(json: result.data) if result.success?

    render json: { message: result.error[:message] }, status: failure_status(result.error[:message])
  end

  # Maps a MoneyTransferService error message onto the HTTP status to render.
  #
  # +message+ - the user-facing error message returned by the service
  def failure_status(message)
    case message
    when MISSING_ACCOUNT_MESSAGE then :not_found
    when UNEXPECTED_ERROR_MESSAGE then :internal_server_error
    else :unprocessable_entity
    end
  end

  # Loads the source account from the path, rendering 404 when it does not exist.
  def load_account
    @account = Account.find_by(id: params[:account_id])
    return if @account

    respond_to do |format|
      format.json { render json: { message: 'Invalid account' }, status: :not_found }
    end
  end

  # Halts the request unless the loaded account belongs to the authenticated user.
  def authorize_account_owner
    return if current_user && current_user.account&.id == @account.id

    respond_to do |format|
      format.json { render json: { message: FORBIDDEN_MESSAGE }, status: :forbidden }
    end
  end
end
