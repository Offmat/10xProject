class NotificationsController < ApplicationController
  def index
    @notifications = Notification.unread.for_user(current_user)
      .includes(notifiable: { game_session: :game })
      .order(created_at: :desc)
  end

  def confirm
    notification = Notification.for_user(current_user).find(params[:id])
    notification.notifiable.confirm!
    notification.mark_as_read!
    redirect_to notifications_path, notice: 'Session confirmed.'
  end

  def reject
    notification = Notification.for_user(current_user).find(params[:id])
    notification.notifiable.reject!
    notification.mark_as_read!
    redirect_to notifications_path, notice: 'Session rejected.'
  end
end
