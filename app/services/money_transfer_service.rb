# frozen_string_literal: true

# Transfers money between two accounts using the +transferAmount+ stored procedure.
#
# Validates that the transfer amount is positive and the source and destination
# accounts are different before delegating to the database procedure.
#
# == Usage
#
#   result = MoneyTransferService.call(1, 2, '50.00')
#   if result.success?
#     puts result.data[:message]  # => "Transfer successful"
#   else
#     puts result.error[:message] # => "Insufficient balance"
#   end
#
class MoneyTransferService < BaseService
  attr_reader :from_account_id, :to_account_id, :amount

  # Creates a new MoneyTransferService instance.
  #
  # All three arguments are required; raises +ArgumentError+ if any is +nil+.
  # +from_account_id+ and +to_account_id+ are coerced to Integer,
  # and +amount+ is coerced to BigDecimal.
  #
  # +from_account_id+ - the id of the source Account
  # +to_account_id+   - the id of the destination Account
  # +amount+          - the transfer amount (String, Integer, or BigDecimal)
  #
  # Raises +ArgumentError+ if any argument is +nil+ or cannot be coerced
  def initialize(from_account_id, to_account_id, amount)
    super()
    if [from_account_id, to_account_id, amount].any?(&:nil?)
      raise ArgumentError, 'from_account_id, to_account_id, amount are required'
    end

    @from_account_id = Integer(from_account_id)
    @to_account_id = Integer(to_account_id)
    @amount = BigDecimal(amount.to_s)
  end

  # Executes the money transfer.
  #
  # Returns a +Response+ with <tt>{ message: 'Transfer successful' }</tt> on success.
  # Returns a +Response+ with an error hash on failure, including:
  # - <tt>'Transfer amount must be positive'</tt> — when +amount+ is zero or negative
  # - <tt>'Cannot transfer to the same account'</tt> — when source equals destination
  # - <tt>'Insufficient balance'</tt> — when the source account lacks funds
  # - <tt>'One or both accounts do not exist'</tt> — when an account id is invalid
  # - <tt>'Transfer failed. Please try again later.'</tt> — for unexpected database errors
  def call
    return Response.new(nil, { message: 'Transfer amount must be positive' }) unless amount.positive?
    return Response.new(nil, { message: 'Cannot transfer to the same account' }) if from_account_id == to_account_id

    execute_transfer
    Response.new({ message: 'Transfer successful' })
  rescue ActiveRecord::StatementInvalid => e
    Response.new(nil, { message: transfer_error_message(e) })
  end

  private

  # Calls the +transferAmount+ MySQL stored procedure with sanitized parameters.
  def execute_transfer
    sanitized_sql = ActiveRecord::Base.sanitize_sql_array(
      ['CALL transferAmount(?, ?, ?)', from_account_id, to_account_id, amount]
    )
    ActiveRecord::Base.connection.execute(sanitized_sql)
  end

  # Maps database error messages to user-friendly strings.
  #
  # +exception+ - an ActiveRecord::StatementInvalid wrapping the database error
  def transfer_error_message(exception)
    db_message = exception.cause&.message.to_s

    case db_message
    when /Insufficient Balance/i then 'Insufficient balance'
    when /do not exist/i then 'One or both accounts do not exist'
    else
      Rails.logger.error("Money transfer failed: #{db_message}")
      'Transfer failed. Please try again later.'
    end
  end
end
