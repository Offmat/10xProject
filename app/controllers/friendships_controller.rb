class FriendshipsController < ApplicationController
  def index
    @friends = current_user.friends
    @incoming = Friendship.incoming_to(current_user).includes(:requester)
    @outgoing = Friendship.outgoing_from(current_user).includes(:addressee)
  end

  def create
    result = Friendships::CreateRequest.call(
      requester: current_user,
      addressee_email: friendship_params[:email]
    )

    redirect_to friendships_path, **flash_for(result.status)
  end

  def accept
    friendship = Friendship.incoming_to(current_user).find(params[:id])
    friendship.accept!
    redirect_to friendships_path, notice: 'Friend request accepted.'
  end

  def decline
    friendship = Friendship.incoming_to(current_user).find(params[:id])
    friendship.decline!
    redirect_to friendships_path, notice: 'Friend request declined.'
  end

  def destroy
    friendship = Friendship.outgoing_from(current_user).find(params[:id])
    friendship.destroy!
    redirect_to friendships_path, notice: 'Friend request cancelled.'
  end

  private

  def friendship_params
    params.require(:friendship).permit(:email)
  end

  def flash_for(status)
    case status
    when :requested
      { notice: 'Friend request sent.' }
    when :auto_accepted
      { notice: "You're now friends — they had already sent you a request." }
    when :already_friends
      { alert: "You're already friends." }
    when :already_requested
      { alert: 'You already have a pending request to that person.' }
    when :self_request
      { alert: "You can't send a friend request to yourself." }
    when :not_found
      { alert: 'No account found with that email.' }
    end
  end
end
