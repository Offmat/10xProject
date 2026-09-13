# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

SEED_PASSWORD = 'Qwertyuiop'

SEED_USER_EMAILS = [
  'alice@example.com',
  'bob@example.com',
  'alex@example.com',
  'carol@example.com'
].freeze

SEED_USER_EMAILS.each do |email|
  User.find_or_create_by!(email: email) do |user|
    user.password = SEED_PASSWORD
    user.password_confirmation = SEED_PASSWORD
  end
end

puts "Seeded users: #{SEED_USER_EMAILS.join(', ')}"

games_file = Rails.root.join('db/seeds/games.yml')
game_entries = YAML.load_file(games_file)

game_entries.each do |attributes|
  game = Game.find_or_initialize_by(wikidata_id: attributes['wikidata_id'])
  game.assign_attributes(attributes)
  game.save!
end

puts "Seeded #{game_entries.size} games from #{games_file.basename}"

alice = User.find_by!(email: 'alice@example.com')
bob = User.find_by!(email: 'bob@example.com')
alex = User.find_by!(email: 'alex@example.com')
carol = User.find_by!(email: 'carol@example.com')
seed_users = [alice, bob, alex, carol]
seed_user_ids = seed_users.map(&:id)

Friendship.where(requester_id: seed_user_ids, addressee_id: seed_user_ids).destroy_all

Friendship.create!(requester: alice, addressee: bob, status: :accepted)
Friendship.create!(requester: alice, addressee: alex, status: :accepted)
Friendship.create!(requester: carol, addressee: alice, status: :pending)

puts 'Seeded friendships: Alice↔Bob (accepted), Alice↔Alex (accepted), Carol→Alice (pending)'
