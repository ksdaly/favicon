class AddSites < ActiveRecord::Migration[5.2]
  def change
    create_table :sites do |t|
      t.string :host, unique: true
      t.string :last_url
      t.string :favicon_url
 
      t.timestamps
    end

    add_index :sites, [:host, :favicon_url]
  end
end
