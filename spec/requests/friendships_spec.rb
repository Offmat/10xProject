require 'rails_helper'

RSpec.describe 'Friendships', type: :request do
  let(:alice) { create(:user, email: 'alice@example.com') }
  let(:bob) { create(:user, email: 'bob@example.com') }
  let(:carol) { create(:user, email: 'carol@example.com') }

  describe 'POST /friendships' do
    before { sign_in_as(alice) }

    it 'sends a friend request by email' do
      post friendships_path, params: { friendship: { email: bob.email } }

      expect(response).to redirect_to(friendships_path)
      follow_redirect!
      expect(response.body).to include('Friend request sent.')

      friendship = Friendship.find_by(requester: alice, addressee: bob)
      expect(friendship).to be_pending
    end

    it 'auto-accepts when the addressee already sent a pending request' do
      create(:friendship, requester: bob, addressee: alice)

      post friendships_path, params: { friendship: { email: bob.email } }

      expect(response).to redirect_to(friendships_path)
      follow_redirect!
      expect(response.body).to include('now friends')

      expect(Friendship.accepted.count).to eq(1)
      expect(alice.friends).to contain_exactly(bob)
    end

    it 'allows re-sending after a decline by reusing the row' do
      declined = create(:friendship, :declined, requester: alice, addressee: bob)

      post friendships_path, params: { friendship: { email: bob.email } }

      expect(response).to redirect_to(friendships_path)
      expect(declined.reload).to be_pending
      expect(Friendship.count).to eq(1)
    end

    it 'returns a distinct flash for an unknown email' do
      post friendships_path, params: { friendship: { email: 'unknown@example.com' } }

      follow_redirect!
      expect(response.body).to include('No account found with that email.')
    end
  end

  describe 'PATCH /friendships/:id/accept' do
    let!(:friendship) { create(:friendship, requester: bob, addressee: alice) }

    before { sign_in_as(alice) }

    it 'accepts an incoming request' do
      patch accept_friendship_path(friendship)

      expect(response).to redirect_to(friendships_path)
      expect(friendship.reload).to be_accepted
      expect(alice.friends).to contain_exactly(bob)
    end

    it 'returns 404 when a non-addressee tries to accept' do
      sign_out
      sign_in_as(carol)

      patch accept_friendship_path(friendship)

      expect(response).to have_http_status(:not_found)
      expect(friendship.reload).to be_pending
    end
  end

  describe 'PATCH /friendships/:id/decline' do
    let!(:friendship) { create(:friendship, requester: bob, addressee: alice) }

    before { sign_in_as(alice) }

    it 'declines an incoming request' do
      patch decline_friendship_path(friendship)

      expect(response).to redirect_to(friendships_path)
      expect(friendship.reload).to be_declined
    end

    it 'returns 404 when a non-addressee tries to decline' do
      sign_out
      sign_in_as(carol)

      patch decline_friendship_path(friendship)

      expect(response).to have_http_status(:not_found)
      expect(friendship.reload).to be_pending
    end
  end

  describe 'DELETE /friendships/:id' do
    let!(:friendship) { create(:friendship, requester: alice, addressee: bob) }

    before { sign_in_as(alice) }

    it 'cancels a pending outgoing request' do
      delete friendship_path(friendship)

      expect(response).to redirect_to(friendships_path)
      expect(Friendship.exists?(friendship.id)).to be(false)
    end

    it 'returns 404 when a non-requester tries to cancel' do
      sign_out
      sign_in_as(bob)

      delete friendship_path(friendship)

      expect(response).to have_http_status(:not_found)
      expect(Friendship.exists?(friendship.id)).to be(true)
    end
  end

  describe 'GET /friendships' do
    before { sign_in_as(alice) }

    it 'renders active friends, incoming, and outgoing sections for the current user' do
      accepted = create(:friendship, :accepted, requester: alice, addressee: bob)
      incoming = create(:friendship, requester: carol, addressee: alice)
      outgoing = create(:friendship, requester: alice, addressee: carol)

      get friendships_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Active friends')
      expect(response.body).to include('Incoming requests')
      expect(response.body).to include('Outgoing requests')
      expect(response.body).to include(bob.email)
      expect(response.body).to include(carol.email)
      expect(response.body).to include('Accept')
      expect(response.body).to include('Decline')
      expect(response.body).to include('Cancel')
      expect(accepted).to be_accepted
    end

    it 'shows empty-state copy when lists are empty' do
      get friendships_path

      expect(response.body).to include('No active friends yet')
      expect(response.body).to include('No incoming requests')
      expect(response.body).to include('No pending outgoing requests')
    end
  end

  describe 'nav badge' do
    it 'shows the incoming request count when authenticated' do
      create(:friendship, requester: bob, addressee: alice)
      create(:friendship, requester: carol, addressee: alice)

      sign_in_as(alice)
      get root_path

      expect(response.body).to include('Friends')
      expect(response.body).to match(/indicator-item badge badge-primary badge-sm[^>]*>2</)
    end

    it 'hides the badge when there are no incoming requests' do
      sign_in_as(alice)

      get root_path

      expect(response.body).to include('Friends')
      expect(response.body).not_to include('indicator-item badge badge-primary badge-sm')
    end
  end

  describe 'authentication' do
    it 'redirects unauthenticated users to sign in' do
      post friendships_path, params: { friendship: { email: bob.email } }

      expect(response).to redirect_to(new_session_path)
    end
  end
end
