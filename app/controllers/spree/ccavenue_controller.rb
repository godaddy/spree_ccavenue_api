module Spree
  class CcavenueController < StoreController

    skip_before_filter :verify_authenticity_token, only: :callback
    # we need this to avoid undefined method truncated_product_description in frontend. Details on: https://coveralls.io/builds/769164
    helper 'spree/orders'
    ssl_required

    # show confirmation page
    def show
      cc_transaction   = provider.build_ccavenue_checkout_transaction(order)
      @redirect_params = ccavenue_redirect_params(order, cc_transaction)
    rescue => e
      log_error(e)
      flash[:error] = Spree.t('ccavenue.generic_failed')
      redirect_to (@order.nil? ? spree.cart_path : checkout_state_path(:payment))
    end

    # return from ccavenue
    def callback
      @cc_params = provider.parse_redirect_response(params['encResp'])
      transaction = ccavenue_transaction || raise(ActiveRecord::RecordNotFound)
      provider.update_transaction_from_redirect_response(transaction, @cc_params)
      if transaction.success?
        payment = order.payments.create!({
                                           :source         => transaction,
                                           :amount         => transaction.ccavenue_amount,
                                           :payment_method => payment_method,
                                           # we set the response code here itself, since when there is no more
                                           # stock, order.next doesn't invoke payment.purchase! and as a result
                                           # the response_code never gets set
                                           :response_code  => transaction.tracking_id
                                         })

        # Make sure it's the right order and total matches (no partial payment for now)
        if order.number != transaction.ccavenue_order_number || order.total != payment.amount
          void!(payment)
          flash[:error] = Spree.t('ccavenue.checkout_payment_error')
          redirect_to checkout_state_path(order.state)
          return
        end
      end

      order.next
      if order.complete?
        flash.notice            = Spree.t('ccavenue.order_processed_successfully')
        session[:order_id]      = nil
        redirect_to completion_route(order)
      else
        flash[:error] = order.errors ? order.errors.full_messages.first : Spree.t('ccavenue.generic_failed')
        redirect_to checkout_state_path(order.state)
      end
    rescue => e
      log_error(e)
      if out_of_stock_error(e)
        void!(payment)

        redirect_to spree.cart_path
      else
        flash[:error] = Spree.t('ccavenue.checkout_payment_error')
        redirect_to @order.nil? ? spree.cart_path : checkout_state_path(current_order.state)
      end
    end

    private

    def out_of_stock_error(e)
      e.respond_to?(:record) && e.record.errors.added?(:count_on_hand, I18n.t('errors.messages.greater_than_or_equal_to', count: 0))
    end

    # so we can catch exceptions while voiding
    def void!(payment)
      Rails.logger.warn "Voiding payment for order: #{order.id} tracking_id: #{payment.source.tracking_id} since out of stock or incorrect order"
      if void_payment(payment)
        flash[:error] = Spree.t('ccavenue.checkout_low_inventory_after_payment_warning')
      else
        flash[:error] = Spree.t('ccavenue.refund_api_call_failed')
      end
    rescue => e
      Rails.logger.error "Error #{e.class} encountered voiding payment/#{payment.id} for order/#{order.id} - #{e.message}"
      flash[:error] = Spree.t('ccavenue.refund_api_call_failed')
    end

    def ccavenue_transaction
      order_number, transaction_id = @cc_params['order_id'].split('-')
      Spree::Ccavenue::Transaction.find(transaction_id)    
    end

    def log_error(e)
      Rails.logger.error "Error #{e.class} on redirect from Ccavenue: #{e.message}"
    end

    def completion_route(order)
      order_path(order)
    end

    # override for delayed job
    def void_payment(payment)
      payment.void_transaction!
    end

    def order
      (@order ||= current_order) || raise(ActiveRecord::RecordNotFound)
    end

    def payment_method
      Spree::PaymentMethod.find(params[:id])
    end

    def provider
      payment_method.provider
    end

    def redirect_url(transaction)
      ccavenue_callback_url(payment_method, protocol: request.local? ? request.protocol : 'https')
    end

    def ccavenue_redirect_params(order, transaction)
      ba         = order.bill_address
      sa         = order.ship_address || order.bill_address
      order_data = {
        order_id:         transaction.gateway_order_number(order),
        amount:           order.total.to_s,
        currency:         order.currency,
        promo_code:       order.coupon_code,

        billing_name:     ba.full_name,
        billing_address:  ba.address1,
        billing_city:     ba.city,
        billing_state:    ba.state.try(:name) || ba.state_name,
        billing_zip:      ba.zipcode,
        billing_country:  ba.country.name,
        billing_tel:      ba.phone,
        billing_email:    order.email,

        delivery_name:    sa.full_name,
        delivery_address: sa.address1,
        delivery_city:    sa.city,
        delivery_state:   sa.state.try(:name) || sa.state_name,
        delivery_zip:     sa.zipcode,
        delivery_country: sa.country.name,
        delivery_tel:     sa.phone,

        redirect_url:     redirect_url(transaction)
      }

      return {
        merchant_id:     provider.merchant_id,
        access_code:     provider.access_code,
        transaction_url: provider.transaction_url,
        enc_request:     provider.build_encrypted_request(transaction, order_data)
      }
    end
  end
end
