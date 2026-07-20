FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}-#{SecureRandom.hex(4)}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
  end
end
