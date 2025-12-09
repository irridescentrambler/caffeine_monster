# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    member_id { nil }
    team_id { nil }

    trait :with_user_and_team do
      association :member, factory: :user
      association :team
    end
  end
end
