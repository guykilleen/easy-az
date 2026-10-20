module Admin
  class BaseController < ApplicationController
    before_action :require_admin_session

    private

    def require_admin_session
      unless session[:admin_authenticated]
        render plain: "Not authorised. Generate a login URL with:\n\n  bin/rails admin:login_url",
               status: :unauthorized
      end
    end
  end
end
