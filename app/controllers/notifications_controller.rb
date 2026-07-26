class NotificationsController < ApplicationController
  def index
    @notifications = Notification.unread.for_user(current_user)
      .includes(notifiable: { game_session: [:game, :creator] })
      .order(created_at: :desc)
  end

  def confirm
    notification = find_actionable_notification
    notification.notifiable.confirm!
    notification.mark_as_read!
    redirect_to notifications_path, notice: 'Session confirmed.'
  end

  def reject
    notification = find_actionable_notification
    notification.notifiable.reject!
    notification.mark_as_read!
    redirect_to notifications_path, notice: 'Session rejected.'
  end

  private

  def find_actionable_notification
    notification = Notification.unread.for_user(current_user).find(params[:id])
    raise ActiveRecord::RecordNotFound unless notification.notifiable.pending?

    notification
  end
end
