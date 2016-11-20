class CreateLogEntries < ActiveRecord::Migration[5.0]
  def change
    create_table :log_entries do |t|
      t.datetime :logged_at
      t.integer :pid

      t.string :method
      t.string :ip

      t.string :uri, limit: 2000
      t.string :uri_path
      t.string :uri_query, limit: 2000
      t.string :uri_fragment

      t.string :controller
      t.string :action
      t.string :format
      t.text :parameters

      t.integer :status_code
      t.float :response_time
      t.float :view_time
      t.float :activerecord_time

      # Force MySQL type of mediumtext
      t.text :content, limit: 16.megabytes - 1
      t.text :exception, limit: 16.megabytes - 1

      t.timestamps
    end

    add_index :log_entries, :logged_at
  end
end
