require 'rails_helper'

RSpec.describe Session, type: :model do
  it 'belongs to a user' do
    user = create(:user)
    session = create(:session, user: user)

    expect(session.user).to eq(user)
  end

  describe '.active' do
    it 'includes sessions created within the lifetime window' do
      user = create(:user)
      active_session = create(:session, user: user, created_at: 29.days.ago)

      expect(described_class.active).to include(active_session)
    end

    it 'excludes sessions older than the lifetime window' do
      user = create(:user)
      stale_session = create(:session, user: user, created_at: 31.days.ago)

      expect(described_class.active).not_to include(stale_session)
    end
  end

  describe '.sweep' do
    it 'deletes only stale sessions and returns the count' do
      user = create(:user)
      stale_session = create(:session, user: user, created_at: 31.days.ago)
      active_session = create(:session, user: user, created_at: 1.day.ago)

      expect(described_class.sweep).to eq(1)
      expect(described_class.exists?(stale_session.id)).to be(false)
      expect(described_class.exists?(active_session.id)).to be(true)
    end
  end
end
