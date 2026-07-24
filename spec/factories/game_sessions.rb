FactoryBot.define do
  factory :game_session do
    association :creator, factory: :user
    association :game
  end
end
