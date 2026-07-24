class CreateGameSessionParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :game_session_participants do |t|
      t.references :game_session, null: false, foreign_key: true
      t.references :user, null: false, default: nil, foreign_key: true
      t.string :guest_name
      t.integer :score, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    change_column_null :game_session_participants, :user_id, true

    add_check_constraint :game_session_participants,
      '(user_id IS NOT NULL AND guest_name IS NULL) OR (user_id IS NULL AND guest_name IS NOT NULL)',
      name: 'participants_exactly_one_identity'

    add_index :game_session_participants, %i[game_session_id user_id],
      unique: true,
      where: 'user_id IS NOT NULL',
      name: 'index_participants_unique_user_per_session'
  end
end
