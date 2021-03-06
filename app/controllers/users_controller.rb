class UsersController < ApplicationController
  skip_before_action :authorized, only: [:new, :create]
  # skip_before_action :current_user, only: [:new, :create]
  before_action :set_minute_options, only: [:new, :edit]

  # get '/register'
  def new
    # show new user form
    @user = User.new
  end

  # post '/register'
  def create
    user = User.create(user_params)
    if user.valid?
      login_user(user)
      redirect_to neighborhoods_path
    else
      flash[:errors] = user.errors.full_messages
      redirect_to register_path
    end
  end

  # get '/profile'
  def show
    @apartments = @user.apartments
    # show user profile
  end

  # get '/profile/edit'
  def edit
    # render edit form
  end

  # patch '/profile/edit'
  def update
    @user.update(user_params)
    if @user.valid?
      redirect_to neighborhoods_path
    else
      flash[:errors] = @user.errors.full_messages
      redirect_to edit_profile_path
    end
  end

  def apartments
    @apartments = @user.apartments
  end

  def add_apartment
    @apartment = Apartment.find_by(id: params["apartment_id"])
    user_apartment = UserApartment.create(user: @user, apartment: @apartment)
    if user_apartment.valid?
      flash[:notice] = "Apartment saved."
    else
      flash[:notice] = "Error saving apartment."
    end
    redirect_to @apartment
  end

  # delete '/profile'
  def destroy
    @user.destroy
    redirect_to root_path
  end

  private

  def user_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :username,
      :password,
      :password_confirmation,
      :work_address,
      :commute_time
    )
  end

  def set_minute_options
    @minute_options = []
    8.times do |i|
      m = (i+1)*15
      @minute_options << [m, "#{m} minutes"]
    end
  end
end

#
