# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoneyTransferService, type: :service do
  describe '#call' do
    let(:from_account_id) { create(:account).id }
    let(:to_account_id) { create(:account).id }
    let(:amount) { 500 }

    context 'when transfer is successful' do
      it 'returns a successful response' do
        from_account = Account.find(from_account_id)
        to_account = Account.find(to_account_id)
        initial_balance_of_from_account = from_account.balance
        initial_balance_of_to_account = to_account.balance
        response = described_class.call(from_account_id, to_account_id, amount)

        expect(response.success?).to be true
        expect(response.data).to eq({ message: 'Transfer successful' })
        expect(response.error).to be_nil
        expect(from_account.reload.balance).to eq(initial_balance_of_from_account - amount)
        expect(to_account.reload.balance).to eq(initial_balance_of_to_account + amount)
      end
    end

    context 'when the stored procedure raises a Mysql2::Error' do
      it 'returns a failed response with the error message' do
        account_balance = Account.find(from_account_id).balance
        response = described_class.call(from_account_id, to_account_id, account_balance + 100)
        expect(response.success?).to be false
        expect(response.data).to be_nil
        expect(response.error).to eq({ message: 'Insufficient balance' })
      end
    end

    context 'when called via class-level .call' do
      it 'instantiates and calls the service' do
        response = described_class.call(from_account_id, to_account_id, amount)

        expect(response.success?).to be true
        expect(response.data).to eq({ message: 'Transfer successful' })
      end
    end
  end

  describe '#initialize' do
    context 'when from_account_id is nil' do
      it 'raises an error' do
        expect { described_class.new(nil, 2, 500) }
          .to raise_error('from_account_id, to_account_id, amount are required')
      end
    end

    context 'when to_account_id is nil' do
      it 'raises an error' do
        expect { described_class.new(1, nil, 500) }
          .to raise_error('from_account_id, to_account_id, amount are required')
      end
    end

    context 'when amount is nil' do
      it 'raises an error' do
        expect { described_class.new(1, 2, nil) }
          .to raise_error('from_account_id, to_account_id, amount are required')
      end
    end
  end
end
