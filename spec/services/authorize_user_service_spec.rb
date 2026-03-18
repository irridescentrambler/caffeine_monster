# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthorizeUserService, type: :service do
  describe '#call' do
    let(:token) { 'jwt-token' }
    let(:headers) do
      {
        'HTTP_AUTHORIZATION' => "Bearer #{token}",
        'AUTHORIZATION' => nil
      }
    end

    context 'when the Bearer token decodes to a user id and the user exists' do
      it 'returns a successful response with the user' do
        user = instance_double(User, id: 42)
        allow(JsonWebToken).to receive(:decode).with(token).and_return({ user_id: 42 })
        allow(User).to receive(:find_by).with(id: 42).and_return(user)

        response = described_class.new(headers).call

        expect(response.success?).to be true
        expect(response.data).to eq({ user: user })
        expect(response.error).to be_nil
      end
    end

    context 'when AUTHORIZATION is set but HTTP_AUTHORIZATION is nil' do
      let(:headers) do
        {
          'HTTP_AUTHORIZATION' => nil,
          'AUTHORIZATION' => "Bearer #{token}"
        }
      end

      it 'uses AUTHORIZATION and returns a successful response' do
        user = instance_double(User, id: 7)
        allow(JsonWebToken).to receive(:decode).with(token).and_return({ user_id: 7 })
        allow(User).to receive(:find_by).with(id: 7).and_return(user)

        response = described_class.new(headers).call

        expect(response.success?).to be true
        expect(response.data[:user]).to eq(user)
      end
    end

    context 'when JsonWebToken.decode returns nil' do
      it 'returns an unauthorized response' do
        allow(JsonWebToken).to receive(:decode).with(token).and_return(nil)

        response = described_class.new(headers).call

        expect(response.success?).to be false
        expect(response.data).to be_nil
        expect(response.error).to eq(:unauthorized)
        expect(User).not_to receive(:find_by)
      end
    end

    context 'when the decoded payload has no user_id' do
      it 'returns an unauthorized response' do
        allow(JsonWebToken).to receive(:decode).with(token).and_return({ user_id: nil })

        response = described_class.new(headers).call

        expect(response.success?).to be false
        expect(response.data).to be_nil
        expect(response.error).to eq(:unauthorized)
        expect(User).not_to receive(:find_by)
      end
    end

    context 'when the user is not found' do
      it 'returns an unauthorized response' do
        allow(JsonWebToken).to receive(:decode).with(token).and_return({ user_id: 99 })
        allow(User).to receive(:find_by).with(id: 99).and_return(nil)

        response = described_class.new(headers).call

        expect(response.success?).to be false
        expect(response.data).to be_nil
        expect(response.error).to eq(:unauthorized)
      end
    end

    context 'when the Authorization header is not Bearer' do
      let(:headers) do
        {
          'HTTP_AUTHORIZATION' => 'Basic abc',
          'AUTHORIZATION' => nil
        }
      end

      it 'returns an unauthorized response' do
        allow(JsonWebToken).to receive(:decode).with(nil).and_return(nil)

        response = described_class.new(headers).call

        expect(response.success?).to be false
        expect(response.error).to eq(:unauthorized)
      end
    end
  end
end
