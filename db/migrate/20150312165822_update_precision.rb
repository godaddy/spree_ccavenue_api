class UpdatePrecision < ActiveRecord::Migration[4.2]
  def change
    change_column :spree_ccavenue_transactions, :amount, :decimal, :precision => 10, :scale => 2
  end
end
