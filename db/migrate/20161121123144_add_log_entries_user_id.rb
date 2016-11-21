class AddLogEntriesUserId < ActiveRecord::Migration[5.0]
  def change
    add_column :log_entries, :user_id, :integer
  end
end
