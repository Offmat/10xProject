class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :name, null: false
      t.string :wikidata_id, null: false
      t.string :description
      t.string :bgg_id
      t.integer :min_players
      t.integer :max_players
      t.integer :year_published
      t.integer :play_time_minutes
      t.string :source, null: false, default: 'wikidata'
      t.datetime :imported_at

      t.timestamps
    end
    add_index :games, :wikidata_id, unique: true
    add_index :games, :bgg_id
  end
end
