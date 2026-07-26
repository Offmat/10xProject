class AddReasonToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :reason, :string, default: 'invitation', null: false
  end
end
