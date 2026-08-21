# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account transfers', type: :request do
  let(:sender) { create(:user) }
  let(:from_account) { create(:account) }
  let(:to_account) { create(:account) }
  let(:token) { JsonWebToken.encode({ user_id: sender.id }) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  before { create(:account_user, user: sender, account: from_account) }

  def transfer(params, request_headers = headers, account = from_account)
    post account_transfer_path(account), params: params, headers: request_headers, as: :json
  end

  describe 'POST /accounts/:account_id/transfer' do
    context 'when the transfer succeeds' do
      it 'returns ok and moves the money' do
        from_balance = from_account.balance
        to_balance = to_account.balance

        transfer({ to_account_id: to_account.id, amount: 500 })

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('Transfer successful')
        expect(from_account.reload.balance).to eq(from_balance - 500)
        expect(to_account.reload.balance).to eq(to_balance + 500)
      end
    end

    context 'when the source account has insufficient balance' do
      it 'returns unprocessable entity and leaves balances untouched' do
        from_balance = from_account.balance
        to_balance = to_account.balance

        transfer({ to_account_id: to_account.id, amount: from_balance + 100 })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to eq('Insufficient balance')
        expect(from_account.reload.balance).to eq(from_balance)
        expect(to_account.reload.balance).to eq(to_balance)
      end
    end

    context 'when transferring to the same account' do
      it 'returns unprocessable entity' do
        transfer({ to_account_id: from_account.id, amount: 100 })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to eq('Cannot transfer to the same account')
      end
    end

    context 'when the amount is not positive' do
      it 'returns unprocessable entity' do
        transfer({ to_account_id: to_account.id, amount: -100 })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to eq('Transfer amount must be positive')
      end
    end

    context 'when the destination account does not exist' do
      it 'returns not found' do
        from_balance = from_account.balance

        transfer({ to_account_id: to_account.id + 10_000, amount: 100 })

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['message']).to eq('One or both accounts do not exist')
        expect(from_account.reload.balance).to eq(from_balance)
      end
    end

    context 'when the source account does not exist' do
      it 'returns not found' do
        transfer({ to_account_id: to_account.id, amount: 100 }, headers, from_account.id + 10_000)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['message']).to eq('Invalid account')
      end
    end

    context 'when amount is missing' do
      it 'returns unprocessable entity' do
        transfer({ to_account_id: to_account.id })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message'])
          .to eq('to_account_id and amount are required and must be numeric')
      end
    end

    context 'when to_account_id is missing' do
      it 'returns unprocessable entity' do
        transfer({ amount: 100 })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message'])
          .to eq('to_account_id and amount are required and must be numeric')
      end
    end

    context 'when amount is not numeric' do
      it 'returns unprocessable entity' do
        transfer({ to_account_id: to_account.id, amount: 'not-a-number' })

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message'])
          .to eq('to_account_id and amount are required and must be numeric')
      end
    end

    context 'when the account belongs to another user' do
      let(:other_account) { create(:account) }

      it 'returns forbidden and leaves balances untouched' do
        other_balance = other_account.balance
        create(:account_user, user: create(:user), account: other_account)

        transfer({ to_account_id: to_account.id, amount: 100 }, headers, other_account)

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['message']).to eq('You are not allowed to transfer from this account')
        expect(other_account.reload.balance).to eq(other_balance)
      end
    end

    context 'when the request is not authenticated' do
      it 'returns unauthorized' do
        from_balance = from_account.balance

        transfer({ to_account_id: to_account.id, amount: 100 }, {})

        expect(response).to have_http_status(:unauthorized)
        expect(from_account.reload.balance).to eq(from_balance)
      end
    end
  end
end
