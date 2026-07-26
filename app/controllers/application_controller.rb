class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_incoming_friend_request_count
  before_action :set_unread_notification_count

  private

  def set_incoming_friend_request_count
    return unless authenticated?

    @incoming_friend_request_count = Friendship.incoming_to(current_user).count
  end

  def set_unread_notification_count
    return unless authenticated?

    @unread_notification_count = Notification.unread.for_user(current_user).count
  end
end
