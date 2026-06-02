require 'rails_helper'

RSpec.describe Session, type: :model do
  it 'belongs to a user' do
    user = create(:user)
    session = create(:session, user: user)

    expect(session.user).to eq(user)
  end
end
