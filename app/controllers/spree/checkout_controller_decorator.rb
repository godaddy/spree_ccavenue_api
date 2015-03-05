module Spree
  CheckoutController.class_eval do
    before_filter :confirm_ccavenue, :only => :update

    private
    def confirm_ccavenue
      return unless (params[:state] == 'payment') && params[:order][:payments_attributes]
      payment_method = PaymentMethod.find(params[:order][:payments_attributes].first[:payment_method_id])
      if payment_method && payment_method.kind_of?(Spree::Gateway::Ccavenue)
        redirect_to ccavenue_order_confirmation_path(payment_method, :order_id => current_order.id)
      end
    end

  end
end