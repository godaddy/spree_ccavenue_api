Spree::Payment.class_eval do

  def status!
    payment_source.status
  end

  def sync!
    payment_source.sync
  end
end