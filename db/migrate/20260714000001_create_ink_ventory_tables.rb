class CreateInkVentoryTables < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.string :name
      t.boolean :admin, null: false, default: false
      t.timestamps
    end
    add_index :users, %i[provider uid], unique: true

    create_table :notification_addresses do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :email, null: false
      t.string :verification_token, null: false
      t.string :unsubscribe_token, null: false
      t.datetime :verified_at
      t.boolean :notifications_enabled, null: false, default: true
      t.timestamps
    end
    add_index :notification_addresses, :verification_token, unique: true
    add_index :notification_addresses, :unsubscribe_token, unique: true

    create_table :sites do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :base_url, null: false
      t.string :parser_kind, null: false
      t.boolean :enabled, null: false, default: true
      t.decimal :min_delay_seconds, null: false, default: 2.0, precision: 5, scale: 2
      t.datetime :last_request_at
      t.datetime :backoff_until
      t.integer :consecutive_failures, null: false, default: 0
      t.timestamps
    end
    add_index :sites, :code, unique: true

    create_table :listings do |t|
      t.references :site, null: false, foreign_key: { on_delete: :cascade }
      t.string :external_id, null: false
      t.string :canonical_url, null: false
      t.string :title
      t.string :currency, null: false, default: "KRW"
      t.bigint :base_price_cents
      t.string :status, null: false, default: "unknown"
      t.json :current_state
      t.json :pending_state
      t.datetime :pending_seen_at
      t.datetime :last_checked_at
      t.datetime :last_success_at
      t.datetime :next_check_at
      t.integer :consecutive_errors, null: false, default: 0
      t.string :etag
      t.string :last_modified
      t.timestamps
    end
    add_index :listings, :canonical_url, unique: true
    add_index :listings, %i[site_id external_id], unique: true
    add_index :listings, :next_check_at

    create_table :variants do |t|
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }
      t.string :external_id, null: false
      t.string :name, null: false
      t.bigint :effective_price_cents
      t.string :availability, null: false, default: "unknown"
      t.integer :visible_quantity
      t.timestamps
    end
    add_index :variants, %i[listing_id external_id], unique: true

    create_table :observations do |t|
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }
      t.json :state, null: false
      t.datetime :observed_at, null: false
      t.timestamps
    end
    add_index :observations, %i[listing_id observed_at]

    create_table :watch_groups do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, default: "관심 상품"
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :subscriptions do |t|
      t.references :watch_group, null: false, foreign_key: { on_delete: :cascade }
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }
      t.string :variant_external_id, null: false, default: ""
      t.bigint :target_price_cents
      t.boolean :target_armed, null: false, default: true
      t.boolean :notify_restock, null: false, default: true
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :subscriptions, %i[watch_group_id listing_id variant_external_id], unique: true, name: "index_subscriptions_on_group_listing_variant"

    create_table :search_queries do |t|
      t.string :query, null: false
      t.string :normalized_query, null: false
      t.datetime :last_searched_at
      t.datetime :next_search_at
      t.timestamps
    end
    add_index :search_queries, :normalized_query, unique: true
    add_index :search_queries, :next_search_at

    create_table :search_watches do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :search_query, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :search_watches, %i[user_id search_query_id], unique: true

    create_table :search_candidates do |t|
      t.references :search_query, null: false, foreign_key: { on_delete: :cascade }
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :first_seen_at, null: false
      t.timestamps
    end
    add_index :search_candidates, %i[search_query_id listing_id], unique: true

    create_table :search_attempts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :search_attempts, %i[user_id created_at]

    create_table :change_events do |t|
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }
      t.references :search_query, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :variant_external_id, null: false, default: ""
      t.json :previous_value, null: false, default: {}
      t.json :current_value, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :change_events, %i[listing_id occurred_at]
    add_index :change_events, %i[kind occurred_at]

    create_table :mail_deliveries do |t|
      t.references :user, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :recipient, null: false
      t.string :dedupe_key, null: false
      t.string :status, null: false, default: "pending"
      t.json :metadata, null: false, default: {}
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :scheduled_at, null: false
      t.datetime :sent_at
      t.timestamps
    end
    add_index :mail_deliveries, :dedupe_key, unique: true
    add_index :mail_deliveries, %i[status scheduled_at]

    create_table :event_receipts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :change_event, null: false, foreign_key: { on_delete: :cascade }
      t.references :mail_delivery, foreign_key: { on_delete: :nullify }
      t.string :channel, null: false, default: "digest"
      t.timestamps
    end
    add_index :event_receipts, %i[user_id change_event_id channel], unique: true, name: "index_event_receipts_on_user_event_channel"
  end
end
