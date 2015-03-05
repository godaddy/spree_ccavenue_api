class RemoveSpuriousColumns < ActiveRecord::Migration
  def change
    remove_column :spree_ccavenue_transactions, :order_id
    remove_column :spree_ccavenue_transactions, :payment_method_id
    remove_column :spree_ccavenue_transactions, :transaction_number
  end
end
