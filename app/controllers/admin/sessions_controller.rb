module Admin
  class SessionsController < ApplicationController
    def new
      payload = Rails.application.message_verifier("admin-login")
                     .verified(params[:token].to_s)

      if payload.is_a?(Hash) && payload[:exp].to_i > Time.now.to_i
        session[:admin_authenticated] = true
        redirect_to admin_store_hours_path, notice: "Welcome back."
      else
        render plain: "Invalid or expired link. Generate a new one with:\n\n  bin/rails admin:login_url",
               status: :unauthorized
      end
    end

    def destroy
      session.delete(:admin_authenticated)
      redirect_to "/", notice: "Logged out."
    end
  end
end
