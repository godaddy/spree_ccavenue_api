require 'api_caller'

module Spree
  class CcavenueController < StoreController

    skip_before_filter :verify_authenticity_token, only: :callback
    helper 'spree/orders' # we need this to avoid undefined method truncated_product_description in frontend. Details on: https://coveralls.io/builds/769164

    ssl_allowed

    def show
      @payment_method = Spree::PaymentMethod.find(params[:payment_method_id])
      @order = current_order
      if @order.has_authorized_ccavenue_transaction?
        flash[:error] = Spree.t('order_number_already_authorized', order_number: @order.number)
        render :error
        return
      end

      @order.cancel_existing_ccavenue_transactions!
      @order.payments.destroy_all
      @order.payments.build(:amount => @order.total, :payment_method_id => @payment_method.id)
      @transaction = @order.ccavenue_transactions.build(:amount => @order.total,
                                                        :currency => @order.currency.to_s,
                                                        :payment_method_id => @payment_method.id)

      @transaction.transact
      @order.save!
      raise Spree.t('order_not_saved', order: @order.inspect) unless @order.persisted?
      logger.info("Sending order #{@order.number} to CCAvenue via transaction id #{@transaction.id}")
      @bill_address, @ship_address = @order.bill_address, (@order.ship_address || @order.bill_address)
    end

    def callback
      @transaction = Spree::Ccavenue::Transaction.find(params[:id])
      raise Spree.t('transaction_not_found', id: params[:id]) unless @transaction

      params = decrypt_ccavenue_response_params
      logger.info "Decrypted params from CCAvenue #{params.inspect}"
      @transaction.auth_desc = params['order_status']
      @transaction.card_category = params['card_name']
      @transaction.ccavenue_order_number = params['order_id']
      @transaction.tracking_id = params['tracking_id']
      @transaction.ccavenue_amount = params['amount']

      session[:access_token] = @transaction.order.guest_token if @transaction.order.respond_to?(:guest_token)
      session[:order_id] = @transaction.order.id

      if @transaction.order.insufficient_stock_lines.present?
        response = @transaction.void
        render Spree.t('refund_failed', reason: response.reason) and return unless response.success?
        update_order_payment_state(@transaction.order)
        redirect_to edit_order_path(@transaction.order), :notice => Spree.t("payment_not_processed")
        return
      end
      if @transaction.next
        handle_successful_transaction
      else
        render 'error'
      end

    end

    private

    def handle_successful_transaction
      if @transaction.authorized? # Successful
        session[:order_id] = nil
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:commerce_tracking] = 'nothing special'
        # We are setting token here so that even if the URL is copied and reused later on the completed order page still gets displayed
        if session[:access_token].nil?
          redirect_to order_path(@transaction.order, {:checkout_complete => true})
        else
          redirect_to order_path(@transaction.order, {:checkout_complete => true, :token => session[:access_token]})
        end
      elsif @transaction.rejected?
        redirect_to edit_order_path(@transaction.order), :error => Spree.t("payment_rejected")
      elsif @transaction.canceled?
        redirect_to edit_order_path(@transaction.order), :notice => Spree.t("payment_canceled")
      elsif @transaction.initiated?
        redirect_to edit_order_path(@transaction.order), :notice => Spree.t("payment_initiated")
      end
    end

    def update_order_payment_state(order)
      order.update_column(:payment_state, 'void')
    end

    def decrypt_ccavenue_response_params
      Rails.logger.info "Received transaction from CCAvenue #{params.inspect}"
      encryption_key = @transaction.payment_method.preferred_encryption_key
      query = AESCrypter.decrypt(params['encResp'], encryption_key)
      Rack::Utils.parse_nested_query(query)
    end
  end
end
