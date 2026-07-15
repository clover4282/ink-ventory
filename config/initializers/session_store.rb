Rails.application.config.session_store :cookie_store,
  key: "_ink_ventory_session",
  expire_after: 30.days,
  same_site: :lax,
  secure: Rails.env.production?
