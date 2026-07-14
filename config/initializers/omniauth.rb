OmniAuth.config.allowed_request_methods = [ :post ]

Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["GOOGLE_CLIENT_ID"].present?
    provider :google_oauth2, ENV.fetch("GOOGLE_CLIENT_ID"), ENV.fetch("GOOGLE_CLIENT_SECRET"), scope: "email,profile"
  end
  if ENV["KAKAO_CLIENT_ID"].present?
    provider :kakao, ENV.fetch("KAKAO_CLIENT_ID"), ENV.fetch("KAKAO_CLIENT_SECRET", ""), scope: "profile_nickname,account_email"
  end
end
