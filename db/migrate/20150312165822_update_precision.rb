class UpdatePrecision < ActiveRecord::Migration
  def change
    change_column :spree_ccavenue_transactions, :amount, :decimal, :precision => 10, :scale => 2
  end
end
