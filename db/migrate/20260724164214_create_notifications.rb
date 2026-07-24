class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.string :notifiable_type, null: false
      t.bigint :notifiable_id, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, %i[recipient_id read_at]
    add_index :notifications, %i[notifiable_type notifiable_id]
  end
end
