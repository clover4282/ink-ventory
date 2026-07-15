class CreateLoginChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :login_challenges do |t|
      t.string :email, null: false
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :sent_at, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :locked_until
      t.timestamps
    end

    add_index :login_challenges, :email, unique: true
    add_index :login_challenges, :expires_at
    add_index :users, :email, unique: true
    add_index :notification_addresses, :email, unique: true
  end
end
