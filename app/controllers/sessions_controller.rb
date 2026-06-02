class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    log_auth_event('sign_in_rate_limited', email: params[:email])
    redirect_to new_session_path, alert: 'Try again later.'
  }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email, :password))
      start_new_session_for user
      log_auth_event('sign_in_success', email: user.email, user_id: user.id)
      redirect_to after_authentication_url
    else
      log_auth_event('sign_in_failure', email: params[:email])
      redirect_to new_session_path, alert: 'Try another email or password.'
    end
  end

  def destroy
    log_auth_event('sign_out', email: current_user&.email, user_id: current_user&.id)
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    def log_auth_event(event, email: nil, user_id: nil)
      AuthAuditLogger.log(
        event: event,
        email: email,
        user_id: user_id,
        ip: request.remote_ip,
        user_agent: request.user_agent
      )
    end
end
