class UpdateIndexForSites < ActiveRecord::Migration[5.2]
  def change
    remove_index :sites, [:host, :favicon_url]
    add_index :sites, [:host, :id, :favicon_url]
  end
end
