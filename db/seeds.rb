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

alice.created_game_sessions.destroy_all

Friendship.where(requester_id: seed_user_ids, addressee_id: seed_user_ids).destroy_all

Friendship.create!(requester: alice, addressee: bob, status: :accepted)
Friendship.create!(requester: alice, addressee: alex, status: :accepted)
Friendship.create!(requester: carol, addressee: alice, status: :pending)

puts 'Seeded friendships: Alice↔Bob (accepted), Alice↔Alex (accepted), Carol→Alice (pending)'

games = Game.order(:id).limit(5).to_a
raise 'Need at least 5 games before seeding sessions' if games.size < 5

seed_session = lambda do |game:, creator_score:, players: []|
  result = GameSessions::Create.call(
    creator: alice,
    game_id: game.id,
    creator_score:,
    players:
  )
  raise "Failed to seed game session (#{result.status})" unless result.status == :created

  result.game_session
end

seed_session.call(game: games[0], creator_score: 42, players: [])
seed_session.call(
  game: games[1],
  creator_score: 30,
  players: [
    { type: 'guest', guest_name: 'Dana', score: 22 },
    { type: 'guest', guest_name: 'Sam', score: 18 }
  ]
)
seed_session.call(
  game: games[2],
  creator_score: 15,
  players: [
    { type: 'friend', user_id: bob.id, score: 20 }
  ]
)
alex_pending_session = seed_session.call(
  game: games[3],
  creator_score: 12,
  players: [
    { type: 'friend', user_id: alex.id, score: 25 }
  ]
)
seed_session.call(
  game: games[4],
  creator_score: 10,
  players: [
    { type: 'friend', user_id: bob.id, score: 18 },
    { type: 'guest', guest_name: 'Dana', score: 14 }
  ]
)

GameSessionParticipant
  .joins(:game_session)
  .where(game_sessions: { creator_id: alice.id })
  .where.not(user_id: [nil, alice.id])
  .where.not(game_session_id: alex_pending_session.id)
  .find_each(&:confirm!)

puts "Seeded #{alice.created_game_sessions.count} Alice game sessions " \
     '(solo, guests, Bob, Alex pending, Bob+guest); friend tags confirmed except Alex pending'
