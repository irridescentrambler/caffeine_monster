# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthenticateUserService, type: :service do
  describe '#call' do
    let(:email) { 'user@example.com' }
    let(:password) { 'secret123' }

    before do
      allow(JsonWebToken).to receive(:encode)
    end

    context 'when credentials are valid' do
      it 'returns a successful response with token data' do
        user = instance_double(User, id: 42)
        allow(User).to receive(:find_by).with(email: email).and_return(user)
        allow(user).to receive(:authenticate).with(password).and_return(true)
        allow(JsonWebToken).to receive(:encode).with({ user_id: 42 }).and_return('jwt-token')

        response = described_class.new(email, password).call

        expect(response.success?).to be true
        expect(response.data).to eq('jwt-token')
        expect(response.error).to be_nil
      end
    end

    context 'when user is not found' do
      it 'returns an unauthorized response' do
        allow(User).to receive(:find_by).with(email: email).and_return(nil)

        response = described_class.new(email, password).call

        expect(response.success?).to be false
        expect(response.data).to be_nil
        expect(response.error).to eq(:unauthorized)
        expect(JsonWebToken).not_to have_received(:encode)
      end
    end

    context 'when password is invalid' do
      it 'returns an unauthorized response' do
        user = instance_double(User, id: 42)
        allow(User).to receive(:find_by).with(email: email).and_return(user)
        allow(user).to receive(:authenticate).with(password).and_return(false)

        response = described_class.new(email, password).call

        expect(response.success?).to be false
        expect(response.data).to be_nil
        expect(response.error).to eq(:unauthorized)
        expect(JsonWebToken).not_to have_received(:encode)
      end
    end
  end
end
