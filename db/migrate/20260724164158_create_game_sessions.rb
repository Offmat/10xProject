class CreateGameSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_sessions do |t|
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :game, null: false, foreign_key: true

      t.timestamps
    end
  end
end
