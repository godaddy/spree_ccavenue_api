require 'api_caller'

Spree::Admin::PaymentMethodsController.class_eval do

  def verify
    payment_method = Spree::PaymentMethod.find(params[:id])
    payment_method.preferred_merchant_id = params[:gateway_ccavenue][:preferred_merchant_id]
    payment_method.preferred_access_code = params[:gateway_ccavenue][:preferred_access_code]
    payment_method.preferred_encryption_key = params[:gateway_ccavenue][:preferred_encryption_key]
    respond_to do |format|
      if payment_method_preferred_params_invalid?(payment_method)
        format.html { render text: 'Verification failed' }
      else
        reason = ApiCaller.status(payment_method, nil, nil).reason
        reason = (reason.include?('Providing Reference_No/Order No is mandatory')) ? 'Verified successfully' : reason
        format.html { render text: reason }
      end
    end
  end

  private

  def payment_method_preferred_params_invalid?(pm)
    pm.preferred_merchant_id.blank? || pm.preferred_access_code.blank? || pm.preferred_encryption_key.blank?
  end

  def ccavenue_gateway?
    params[:payment_method][:type] == 'Spree::Gateway::Ccavenue'
  end

end