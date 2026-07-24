module GameSessions
  CreateResult = Data.define(:status, :game_session)

  class Create
    def self.call(creator:, game_id:, creator_score:, players: [])
      new(creator:, game_id:, creator_score:, players:).call
    end

    def initialize(creator:, game_id:, creator_score:, players:)
      @creator = creator
      @game_id = game_id
      @creator_score = creator_score
      @players = players.reject { |p| p[:user_id].to_s == creator.id.to_s }
    end

    def call
      game = Game.find_by(id: game_id)
      return result(:game_not_found) unless game

      non_friend_ids = validate_friendships
      return result(:not_friends) if non_friend_ids.any?

      GameSession.transaction do
        game_session = GameSession.create!(creator: creator, game: game)

        create_logger_participant(game_session)
        create_other_participants(game_session)

        result(:created, game_session)
      end
    rescue ActiveRecord::RecordInvalid
      result(:invalid)
    end

    private

    attr_reader :creator, :game_id, :creator_score, :players

    def validate_friendships
      registered_user_ids = players.filter_map { |p| p[:user_id] if p[:type] == 'friend' }
      return [] if registered_user_ids.empty?

      friend_ids = creator.friends.where(id: registered_user_ids).pluck(:id)
      registered_user_ids.map(&:to_i) - friend_ids
    end

    def create_logger_participant(game_session)
      game_session.game_session_participants.create!(
        user: creator,
        score: creator_score,
        status: :confirmed
      )
    end

    def create_other_participants(game_session)
      players.each do |player_data|
        if player_data[:type] == 'friend'
          create_registered_participant(game_session, player_data)
        else
          create_guest_participant(game_session, player_data)
        end
      end
    end

    def create_registered_participant(game_session, player_data)
      participant = game_session.game_session_participants.create!(
        user_id: player_data[:user_id],
        score: player_data[:score],
        status: :pending
      )
      Notification.create!(recipient_id: player_data[:user_id], notifiable: participant)
    end

    def create_guest_participant(game_session, player_data)
      game_session.game_session_participants.create!(
        guest_name: player_data[:guest_name],
        score: player_data[:score],
        status: :confirmed
      )
    end

    def result(status, game_session = nil)
      CreateResult.new(status:, game_session:)
    end
  end
end
