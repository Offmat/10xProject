FactoryBot.define do
  factory :notification do
    association :recipient, factory: :user
    association :notifiable, factory: :game_session_participant
  end
end
