module CurrentUser

  def self.lookup_from_env(env)
    request = Rack::Request.new(env)
    lookup_from_auth_token(request.cookies["_t"])
  end

  def self.lookup_from_auth_token(auth_token)
    if auth_token && auth_token.length == 32
      User.where(auth_token: auth_token).first 
    end
  end

  def log_on_user(user)
    session[:current_user_id] = user.id
    unless user.auth_token
      user.auth_token = SecureRandom.hex(16)
      user.save!
    end
    cookies.permanent[:_t] = { :value => user.auth_token, :httponly => true }
  end

  def current_user
    return @current_user if @current_user || @not_logged_in

    if session[:current_user_id].blank?
      # maybe we have a cookie? 
      @current_user = CurrentUser.lookup_from_auth_token(cookies["_t"])
      session[:current_user_id] = @current_user.id if @current_user
    else
      @current_user ||= User.where(id: session[:current_user_id]).first
    end

    if @current_user && @current_user.is_banned? 
      @current_user = nil
    end

    @not_logged_in = session[:current_user_id].blank?
    if @current_user
      @current_user.update_last_seen! 
      @current_user.update_ip_address!(request.remote_ip)
    end
    @current_user
  end

end
