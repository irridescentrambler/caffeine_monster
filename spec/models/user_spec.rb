# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'creates a user with unique email' do
      user1 = create(:user)
      user2 = create(:user)
      expect(user1.email).not_to eq(user2.email)
    end
  end

  describe 'validations' do
    describe 'email uniqueness' do
      it 'is valid with a unique email' do
        user = build(:user, email: 'unique@example.com')
        expect(user).to be_valid
      end

      it 'is invalid with a duplicate email' do
        create(:user, email: 'duplicate@example.com')
        duplicate_user = build(:user, email: 'duplicate@example.com')

        expect(duplicate_user).not_to be_valid
        expect(duplicate_user.errors[:email]).to include('has already been taken')
      end

      it 'is case-sensitive for email uniqueness' do
        create(:user, email: 'test@example.com')
        user_with_different_case = build(:user, email: 'TEST@example.com')
        # By default, Rails uniqueness validation is case-sensitive
        expect(user_with_different_case).to be_valid
      end
    end
  end

  describe 'associations' do
    describe '#account_user' do
      it 'can have one account_user' do
        user = create(:user)
        account = create(:account)
        account_user = create(:account_user, user: user, account: account)

        expect(user.account_user).to eq(account_user)
      end

      it 'returns nil when no account_user exists' do
        user = create(:user)
        expect(user.account_user).to be_nil
      end
    end

    describe '#account' do
      it 'can access account through account_user' do
        user = create(:user)
        account = create(:account, balance: 5000)
        create(:account_user, user: user, account: account)

        expect(user.account).to eq(account)
        expect(user.account.balance).to eq(5000)
      end

      it 'returns nil when no account exists' do
        user = create(:user)
        expect(user.account).to be_nil
      end
    end

    describe '#memberships' do
      let(:user) { create(:user) }
      let(:team1) { create(:team, name: 'Team Alpha') }
      let(:team2) { create(:team, name: 'Team Beta') }

      it 'can have many memberships' do
        membership1 = create(:membership, member_id: user.id, team_id: team1.id)
        membership2 = create(:membership, member_id: user.id, team_id: team2.id)

        expect(user.memberships.count).to eq(2)
        expect(user.memberships).to include(membership1, membership2)
      end

      it 'returns empty collection when no memberships exist' do
        expect(user.memberships).to be_empty
      end
    end

    describe '#teams' do
      let(:user) { create(:user) }
      let(:team1) { create(:team, name: 'Engineering') }
      let(:team2) { create(:team, name: 'Design') }

      it 'can access teams through memberships' do
        create(:membership, member_id: user.id, team_id: team1.id)
        create(:membership, member_id: user.id, team_id: team2.id)

        expect(user.teams.count).to eq(2)
        expect(user.teams).to include(team1, team2)
      end

      it 'returns empty collection when not a member of any team' do
        expect(user.teams).to be_empty
      end
    end
  end

  describe 'CRUD operations' do
    describe 'create' do
      it 'creates a user with valid attributes' do
        user = User.create(name: 'John Doe', email: 'john@example.com')

        expect(user).to be_persisted
        expect(user.name).to eq('John Doe')
        expect(user.email).to eq('john@example.com')
      end

      it 'sets timestamps on creation' do
        user = create(:user)

        expect(user.created_at).to be_present
        expect(user.updated_at).to be_present
      end

      it 'creates user without name (name is optional)' do
        user = User.create(email: 'nameless@example.com')

        expect(user).to be_persisted
        expect(user.name).to be_nil
      end
    end

    describe 'read' do
      it 'finds user by id' do
        created_user = create(:user)
        found_user = User.find(created_user.id)

        expect(found_user).to eq(created_user)
      end

      it 'finds user by email' do
        created_user = create(:user, email: 'findme@example.com')
        found_user = User.find_by(email: 'findme@example.com')

        expect(found_user).to eq(created_user)
      end

      it 'returns nil when user not found by email' do
        found_user = User.find_by(email: 'nonexistent@example.com')

        expect(found_user).to be_nil
      end

      it 'raises error when user not found by id' do
        expect { User.find(99_999) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'update' do
      it 'updates user name' do
        user = create(:user, name: 'Original Name')
        user.update(name: 'Updated Name')

        expect(user.reload.name).to eq('Updated Name')
      end

      it 'updates user email' do
        user = create(:user, email: 'original@example.com')
        user.update(email: 'updated@example.com')

        expect(user.reload.email).to eq('updated@example.com')
      end

      it 'fails to update with duplicate email' do
        create(:user, email: 'existing@example.com')
        user = create(:user, email: 'original@example.com')

        result = user.update(email: 'existing@example.com')

        expect(result).to be false
        expect(user.errors[:email]).to include('has already been taken')
      end

      it 'updates updated_at timestamp' do
        user = create(:user)
        original_updated_at = user.updated_at

        travel_to 1.hour.from_now do
          user.update(name: 'New Name')
          expect(user.updated_at).to be > original_updated_at
        end
      end
    end

    describe 'delete' do
      it 'deletes a user' do
        user = create(:user)
        user_id = user.id

        user.destroy

        expect(User.find_by(id: user_id)).to be_nil
      end

      it 'decreases user count by 1' do
        user = create(:user)

        expect { user.destroy }.to change(User, :count).by(-1)
      end
    end
  end

  describe 'scopes and queries' do
    before do
      create(:user, name: 'Alice', email: 'alice@example.com')
      create(:user, name: 'Bob', email: 'bob@example.com')
      create(:user, name: 'Charlie', email: 'charlie@test.com')
    end

    it 'can find users with where clause' do
      users = User.where('email LIKE ?', '%@example.com')

      expect(users.count).to eq(2)
    end

    it 'can order users by name' do
      users = User.order(:name)

      expect(users.first.name).to eq('Alice')
      expect(users.last.name).to eq('Charlie')
    end

    it 'can limit results' do
      users = User.limit(2)

      expect(users.count).to eq(2)
    end
  end

  describe 'edge cases' do
    it 'handles empty string email' do
      user = build(:user, email: '')
      # Empty string is allowed as there's no presence validation
      expect(user).to be_valid
    end

    it 'handles nil email' do
      user = build(:user, email: nil)
      # Nil email is allowed as there's no presence validation
      expect(user).to be_valid
    end

    it 'handles very long email addresses' do
      long_email = "#{'a' * 200}@example.com"
      user = build(:user, email: long_email)

      # Depends on database column length constraints
      expect(user).to be_valid
    end

    it 'handles special characters in name' do
      user = create(:user, name: "O'Brien-Smith Jr.")

      expect(user.reload.name).to eq("O'Brien-Smith Jr.")
    end

    it 'handles unicode characters in name' do
      user = create(:user, name: '日本語ユーザー')

      expect(user.reload.name).to eq('日本語ユーザー')
    end
  end

  describe 'association dependency' do
    it 'user can be deleted even with account_user association' do
      user = create(:user)
      account = create(:account)
      create(:account_user, user: user, account: account)

      # This test verifies behavior - may need dependent: :destroy if this should cascade
      expect { user.destroy }.to change(User, :count).by(-1)
    end
  end
end
