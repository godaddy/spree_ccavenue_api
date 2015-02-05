class AddTrackingIdToCcavenueTransactions < ActiveRecord::Migration
  def change
    add_column :spree_ccavenue_transactions, :tracking_id, :string
  end
end
