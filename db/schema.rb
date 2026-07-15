# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_15_000001) do
  create_table "change_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "current_value", default: {}, null: false
    t.string "kind", null: false
    t.bigint "listing_id", null: false
    t.datetime "occurred_at", null: false
    t.json "previous_value", default: {}, null: false
    t.bigint "search_query_id"
    t.datetime "updated_at", null: false
    t.string "variant_external_id", default: "", null: false
    t.index ["kind", "occurred_at"], name: "index_change_events_on_kind_and_occurred_at"
    t.index ["listing_id", "occurred_at"], name: "index_change_events_on_listing_id_and_occurred_at"
    t.index ["listing_id"], name: "index_change_events_on_listing_id"
    t.index ["search_query_id"], name: "index_change_events_on_search_query_id"
  end

  create_table "event_receipts", force: :cascade do |t|
    t.bigint "change_event_id", null: false
    t.string "channel", default: "digest", null: false
    t.datetime "created_at", null: false
    t.bigint "mail_delivery_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["change_event_id"], name: "index_event_receipts_on_change_event_id"
    t.index ["mail_delivery_id"], name: "index_event_receipts_on_mail_delivery_id"
    t.index ["user_id", "change_event_id", "channel"], name: "index_event_receipts_on_user_event_channel", unique: true
    t.index ["user_id"], name: "index_event_receipts_on_user_id"
  end

  create_table "listing_likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "listing_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["listing_id", "user_id"], name: "index_listing_likes_on_listing_id_and_user_id", unique: true
    t.index ["listing_id"], name: "index_listing_likes_on_listing_id"
    t.index ["user_id"], name: "index_listing_likes_on_user_id"
  end

  create_table "listings", force: :cascade do |t|
    t.bigint "base_price_cents"
    t.string "canonical_url", null: false
    t.integer "clicks_count", default: 0, null: false
    t.integer "consecutive_errors", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "KRW", null: false
    t.json "current_state"
    t.string "etag"
    t.string "external_id", null: false
    t.string "image_url"
    t.datetime "last_checked_at"
    t.string "last_modified"
    t.datetime "last_success_at"
    t.integer "likes_count", default: 0, null: false
    t.datetime "next_check_at"
    t.datetime "pending_seen_at"
    t.json "pending_state"
    t.bigint "site_id", null: false
    t.string "status", default: "unknown", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["canonical_url"], name: "index_listings_on_canonical_url", unique: true
    t.index ["next_check_at"], name: "index_listings_on_next_check_at"
    t.index ["site_id", "external_id"], name: "index_listings_on_site_id_and_external_id", unique: true
    t.index ["site_id"], name: "index_listings_on_site_id"
  end

  create_table "login_challenges", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.datetime "locked_until"
    t.datetime "sent_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_login_challenges_on_email", unique: true
    t.index ["expires_at"], name: "index_login_challenges_on_expires_at"
  end

  create_table "mail_deliveries", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "dedupe_key", null: false
    t.string "kind", null: false
    t.text "last_error"
    t.json "metadata", default: {}, null: false
    t.string "recipient", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["dedupe_key"], name: "index_mail_deliveries_on_dedupe_key", unique: true
    t.index ["status", "scheduled_at"], name: "index_mail_deliveries_on_status_and_scheduled_at"
    t.index ["user_id"], name: "index_mail_deliveries_on_user_id"
  end

  create_table "notification_addresses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "notifications_enabled", default: true, null: false
    t.string "unsubscribe_token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "verification_token", null: false
    t.datetime "verified_at"
    t.index ["email"], name: "index_notification_addresses_on_email", unique: true
    t.index ["unsubscribe_token"], name: "index_notification_addresses_on_unsubscribe_token", unique: true
    t.index ["user_id"], name: "index_notification_addresses_on_user_id", unique: true
    t.index ["verification_token"], name: "index_notification_addresses_on_verification_token", unique: true
  end

  create_table "observations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "listing_id", null: false
    t.datetime "observed_at", null: false
    t.json "state", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id", "observed_at"], name: "index_observations_on_listing_id_and_observed_at"
    t.index ["listing_id"], name: "index_observations_on_listing_id"
  end

  create_table "search_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_search_attempts_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_search_attempts_on_user_id"
  end

  create_table "search_candidates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "first_seen_at", null: false
    t.bigint "listing_id", null: false
    t.bigint "search_query_id", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_search_candidates_on_listing_id"
    t.index ["search_query_id", "listing_id"], name: "index_search_candidates_on_search_query_id_and_listing_id", unique: true
    t.index ["search_query_id"], name: "index_search_candidates_on_search_query_id"
  end

  create_table "search_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_searched_at"
    t.datetime "next_search_at"
    t.string "normalized_query", null: false
    t.string "query", null: false
    t.datetime "updated_at", null: false
    t.index ["next_search_at"], name: "index_search_queries_on_next_search_at"
    t.index ["normalized_query"], name: "index_search_queries_on_normalized_query", unique: true
  end

  create_table "search_watches", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "search_query_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["search_query_id"], name: "index_search_watches_on_search_query_id"
    t.index ["user_id", "search_query_id"], name: "index_search_watches_on_user_id_and_search_query_id", unique: true
    t.index ["user_id"], name: "index_search_watches_on_user_id"
  end

  create_table "sites", force: :cascade do |t|
    t.datetime "backoff_until"
    t.string "base_url", null: false
    t.string "code", null: false
    t.integer "consecutive_failures", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "last_request_at"
    t.decimal "min_delay_seconds", precision: 5, scale: 2, default: "2.0", null: false
    t.string "name", null: false
    t.string "parser_kind", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_sites_on_code", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "listing_id", null: false
    t.boolean "notify_restock", default: true, null: false
    t.boolean "target_armed", default: true, null: false
    t.bigint "target_price_cents"
    t.datetime "updated_at", null: false
    t.string "variant_external_id", default: "", null: false
    t.bigint "watch_group_id", null: false
    t.index ["listing_id"], name: "index_subscriptions_on_listing_id"
    t.index ["watch_group_id", "listing_id", "variant_external_id"], name: "index_subscriptions_on_group_listing_variant", unique: true
    t.index ["watch_group_id"], name: "index_subscriptions_on_watch_group_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.string "availability", default: "unknown", null: false
    t.datetime "created_at", null: false
    t.bigint "effective_price_cents"
    t.string "external_id", null: false
    t.bigint "listing_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "visible_quantity"
    t.index ["listing_id", "external_id"], name: "index_variants_on_listing_id_and_external_id", unique: true
    t.index ["listing_id"], name: "index_variants_on_listing_id"
  end

  create_table "watch_groups", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", default: "관심 상품", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_watch_groups_on_user_id"
  end

  add_foreign_key "change_events", "listings", on_delete: :cascade
  add_foreign_key "change_events", "search_queries", on_delete: :cascade
  add_foreign_key "event_receipts", "change_events", on_delete: :cascade
  add_foreign_key "event_receipts", "mail_deliveries", on_delete: :nullify
  add_foreign_key "event_receipts", "users", on_delete: :cascade
  add_foreign_key "listing_likes", "listings", on_delete: :cascade
  add_foreign_key "listing_likes", "users", on_delete: :cascade
  add_foreign_key "listings", "sites", on_delete: :cascade
  add_foreign_key "mail_deliveries", "users", on_delete: :cascade
  add_foreign_key "notification_addresses", "users", on_delete: :cascade
  add_foreign_key "observations", "listings", on_delete: :cascade
  add_foreign_key "search_attempts", "users", on_delete: :cascade
  add_foreign_key "search_candidates", "listings", on_delete: :cascade
  add_foreign_key "search_candidates", "search_queries", on_delete: :cascade
  add_foreign_key "search_watches", "search_queries", on_delete: :cascade
  add_foreign_key "search_watches", "users", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "subscriptions", "listings", on_delete: :cascade
  add_foreign_key "subscriptions", "watch_groups", on_delete: :cascade
  add_foreign_key "variants", "listings", on_delete: :cascade
  add_foreign_key "watch_groups", "users", on_delete: :cascade
end
