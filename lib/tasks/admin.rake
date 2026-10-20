namespace :admin do
  desc "Print a magic login URL for the admin area (expires in 1 hour)"
  task login_url: :environment do
    token = Rails.application.message_verifier("admin-login")
                 .generate({ exp: 1.hour.from_now.to_i })
    host  = ENV.fetch("RAILS_HOST", "https://ez-az.net")
    puts "#{host}/admin/login?token=#{CGI.escape(token)}"
    puts "(expires in 1 hour)"
  end
end
