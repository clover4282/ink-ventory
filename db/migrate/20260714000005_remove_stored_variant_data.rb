class RemoveStoredVariantData < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM variants"
    execute "UPDATE listings SET current_state = json_remove(current_state, '$.variants') WHERE current_state IS NOT NULL"
    execute "UPDATE listings SET pending_state = json_remove(pending_state, '$.variants') WHERE pending_state IS NOT NULL"
    execute "UPDATE observations SET state = json_remove(state, '$.variants')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
