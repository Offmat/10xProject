class AddFriendshipsNoSelfCheck < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :friendships,
                         'requester_id <> addressee_id',
                         name: 'friendships_requester_ne_addressee'
  end
end
