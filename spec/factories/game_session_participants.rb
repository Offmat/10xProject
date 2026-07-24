FactoryBot.define do
  factory :game_session_participant do
    association :game_session
    association :user
    sequence(:score) { |n| n * 10 }
    status { :pending }

    trait :guest do
      user { nil }
      sequence(:guest_name) { |n| "Guest #{n}" }
    end

    trait :confirmed do
      status { :confirmed }
    end

    trait :rejected do
      status { :rejected }
    end
  end
end
