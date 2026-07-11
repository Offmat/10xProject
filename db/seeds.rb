# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

games_file = Rails.root.join('db/seeds/games.yml')
game_entries = YAML.load_file(games_file)

game_entries.each do |attributes|
  game = Game.find_or_initialize_by(wikidata_id: attributes['wikidata_id'])
  game.assign_attributes(attributes)
  game.save!
end

puts "Seeded #{game_entries.size} games from #{games_file.basename}"
