# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JsonWebToken do
  describe '.encode' do
    it 'adds exp to the payload and returns a JWT string' do
      freeze_time do
        payload = { user_id: 99 }
        token = described_class.encode(payload)

        expect(token).to be_a(String)
        expect(token.split('.').size).to eq(3)
        expect(payload[:exp]).to eq(24.hours.from_now.to_i)
      end
    end

    it 'uses the given expiration time' do
      exp = 2.hours.from_now
      payload = { sub: 'abc' }
      described_class.encode(payload, exp)

      expect(payload[:exp]).to eq(exp.to_i)
    end
  end

  describe '.decode' do
    it 'returns the payload with indifferent access for a valid token' do
      token = described_class.encode({ user_id: 7 })

      decoded = described_class.decode(token)

      expect(decoded[:user_id]).to eq(7)
      expect(decoded['user_id']).to eq(7)
    end

    it 'returns nil when the token has expired' do
      token = described_class.encode({ user_id: 1 }, 1.hour.ago)

      expect(described_class.decode(token)).to be_nil
    end

    it 'returns nil when the token is malformed' do
      expect(described_class.decode('not-a-jwt')).to be_nil
    end

    it 'returns nil when the token was signed with a different secret' do
      other_token = JWT.encode({ user_id: 1, exp: 1.hour.from_now.to_i }, 'wrong-secret')

      expect(described_class.decode(other_token)).to be_nil
    end
  end
end
