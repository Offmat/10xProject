class GameSessionsController < ApplicationController
  def index
    @game_sessions = GameSession.visible_to(current_user)
      .includes(:game, game_session_participants: :user)
      .order(created_at: :desc)
  end

  def show
    @game_session = GameSession.visible_to(current_user)
      .includes(game_session_participants: :user)
      .find(params[:id])
  end

  def new
    @game_session = GameSession.new
    load_form_data
  end

  def create
    result = GameSessions::Create.call(
      creator: current_user,
      game_id: session_params[:game_id],
      creator_score: session_params[:creator_score],
      players: build_players_array
    )

    case result.status
    when :created
      redirect_to game_sessions_path, notice: 'Session logged successfully.'
    when :game_not_found
      flash.now[:alert] = 'Selected game not found.'
      @game_session = GameSession.new
      load_form_data
      render :new, status: :unprocessable_entity
    when :not_friends
      flash.now[:alert] = 'One or more tagged players are not your friends.'
      @game_session = GameSession.new
      load_form_data
      render :new, status: :unprocessable_entity
    when :invalid
      flash.now[:alert] = 'Could not log session. Please check your input.'
      @game_session = GameSession.new
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @game_session = GameSession.created_by(current_user).find(params[:id])
    load_form_data
  end

  def update
    @game_session = GameSession.created_by(current_user).find(params[:id])

    result = GameSessions::Update.call(
      game_session: @game_session,
      game_id: session_params[:game_id],
      creator_score: session_params[:creator_score],
      players: build_players_array
    )

    case result.status
    when :updated
      redirect_to game_session_path(@game_session), notice: 'Session updated successfully.'
    when :game_not_found
      flash.now[:alert] = 'Selected game not found.'
      load_form_data
      render :edit, status: :unprocessable_entity
    when :not_friends
      flash.now[:alert] = 'One or more tagged players are not your friends.'
      load_form_data
      render :edit, status: :unprocessable_entity
    when :invalid
      flash.now[:alert] = 'Could not update session. Please check your input.'
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_form_data
    @games = Game.order(:name)
    @friends = current_user.friends.order(:email)
  end

  def session_params
    params.require(:game_session).permit(:game_id, :creator_score, players: {})
  end

  def build_players_array
    raw_players = params.dig(:game_session, :players)
    return [] unless raw_players.is_a?(ActionController::Parameters)

    raw_players.values.map do |p|
      {
        id: p[:id].presence,
        type: p[:type],
        user_id: p[:user_id].presence,
        guest_name: p[:guest_name].presence,
        score: p[:score]
      }
    end
  end
end
