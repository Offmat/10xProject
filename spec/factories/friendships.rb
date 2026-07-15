FactoryBot.define do
  factory :friendship do
    association :requester, factory: :user
    association :addressee, factory: :user
    status { :pending }

    trait :accepted do
      status { :accepted }
    end

    trait :declined do
      status { :declined }
    end
  end
end
