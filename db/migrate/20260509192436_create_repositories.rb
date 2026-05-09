class CreateRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :repositories do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :ingested_at

      t.timestamps
    end

    add_index :repositories, :url, unique: true
  end
end
