FactoryBot.define do
  factory :game do
    sequence(:name) { |n| "Board Game #{n}" }
    sequence(:wikidata_id) { |n| "Q#{n}" }
    source { 'wikidata' }
  end
end
