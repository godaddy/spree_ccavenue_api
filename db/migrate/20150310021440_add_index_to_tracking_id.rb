class AddIndexToTrackingId < ActiveRecord::Migration[4.2]
  def change
     add_index :spree_ccavenue_transactions, :tracking_id, :name => 'ccavenue_tracking_id'
  end
end
