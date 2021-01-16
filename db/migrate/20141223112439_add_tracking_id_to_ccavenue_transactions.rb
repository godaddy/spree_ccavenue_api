class AddTrackingIdToCcavenueTransactions < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_ccavenue_transactions, :tracking_id, :string
  end
end
