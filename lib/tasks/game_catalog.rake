namespace :game_catalog do
  desc 'Import games from Wikidata using db/seeds/mvp_seed_list.yml'
  task import: :environment do
    result = GameCatalog::ImportService.call
    puts "Games: #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped]} skipped"
    result[:warnings].each { |warning| puts "  WARN: #{warning}" } if result[:warnings].any?
  end
end
