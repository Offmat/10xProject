module GameSessions
  UpdateResult = Data.define(:status, :game_session)

  class Update
    def self.call(game_session:, game_id:, creator_score:, players: [])
      new(game_session:, game_id:, creator_score:, players:).call
    end

    def initialize(game_session:, game_id:, creator_score:, players:)
      @game_session = game_session
      @game_id = game_id
      @creator_score = creator_score
      @players = players.reject { |p| p[:user_id].to_s == game_session.creator_id.to_s }
    end

    def call
      game = Game.find_by(id: game_id)
      return result(:game_not_found) unless game

      non_friend_ids = validate_friendships
      return result(:not_friends) if non_friend_ids.any?

      GameSession.transaction do
        game_changed = game_session.game_id != game.id
        game_session.update!(game: game)

        update_logger_score
        sync_participants(game_changed)

        result(:updated, game_session.reload)
      end
    rescue ActiveRecord::RecordInvalid
      result(:invalid)
    end

    private

    attr_reader :game_session, :game_id, :creator_score, :players

    def validate_friendships
      registered_user_ids = players.filter_map { |p| p[:user_id] if p[:type] == 'friend' }
      return [] if registered_user_ids.empty?

      friend_ids = game_session.creator.friends.where(id: registered_user_ids).pluck(:id)
      registered_user_ids.map(&:to_i) - friend_ids
    end

    def update_logger_score
      logger_participant = game_session.game_session_participants.find_by(user: game_session.creator)
      logger_participant.update!(score: creator_score)
    end

    def sync_participants(game_changed)
      existing = non_logger_participants
      submitted_ids = players.filter_map { |p| p[:id]&.to_i }

      remove_missing_participants(existing, submitted_ids)

      if game_changed
        apply_submitted_fields(existing)
        reset_all_registered_participants
      else
        update_existing_participants(existing)
      end

      add_new_participants
    end

    def remove_missing_participants(existing, submitted_ids)
      existing.where.not(id: submitted_ids).destroy_all
    end

    def non_logger_participants
      game_session.game_session_participants
        .where('user_id != ? OR user_id IS NULL', game_session.creator_id)
    end

    def apply_submitted_fields(existing)
      players.select { |p| p[:id].present? }.each do |player_data|
        participant = existing.find_by(id: player_data[:id])
        next unless participant

        if participant.registered?
          participant.update!(score: player_data[:score])
        elsif participant.guest?
          participant.update!(
            guest_name: player_data[:guest_name] || participant.guest_name,
            score: player_data[:score]
          )
        end
      end
    end

    def reset_all_registered_participants
      non_logger_participants.where.not(user_id: nil).find_each do |participant|
        reason = participant.rejected? ? 'update_after_rejection' : 'update'
        participant.notifications.destroy_all
        participant.update!(status: :pending)
        Notification.create!(recipient: participant.user, notifiable: participant, reason: reason)
      end
    end

    def update_existing_participants(existing)
      players.select { |p| p[:id].present? }.each do |player_data|
        participant = existing.find_by(id: player_data[:id])
        next unless participant

        if participant.registered? && participant.score != player_data[:score].to_i
          reason = participant.rejected? ? 'update_after_rejection' : 'update'
          participant.notifications.destroy_all
          participant.update!(score: player_data[:score], status: :pending)
          Notification.create!(recipient: participant.user, notifiable: participant, reason: reason)
        elsif participant.guest?
          participant.update!(
            guest_name: player_data[:guest_name] || participant.guest_name,
            score: player_data[:score]
          )
        end
      end
    end

    def add_new_participants
      players.select { |p| p[:id].blank? }.each do |player_data|
        if player_data[:type] == 'friend'
          participant = game_session.game_session_participants.create!(
            user_id: player_data[:user_id],
            score: player_data[:score],
            status: :pending
          )
          Notification.create!(recipient_id: player_data[:user_id], notifiable: participant)
        else
          game_session.game_session_participants.create!(
            guest_name: player_data[:guest_name],
            score: player_data[:score],
            status: :confirmed
          )
        end
      end
    end

    def result(status, game_session = nil)
      UpdateResult.new(status:, game_session:)
    end
  end
end
