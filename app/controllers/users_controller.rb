class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 3, within: 1.minute, only: :create, with: -> {
    redirect_to new_user_path, alert: 'Try again later.'
  }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: 'Welcome to all-aBoard!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end
end
