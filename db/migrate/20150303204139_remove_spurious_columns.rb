class RemoveSpuriousColumns < ActiveRecord::Migration[4.2]
  def change
    remove_column :spree_ccavenue_transactions, :order_id, :integer
    remove_column :spree_ccavenue_transactions, :payment_method_id, :integer
    remove_column :spree_ccavenue_transactions, :transaction_number, :string
  end
end
