RSpec.describe Spree::Gateway::Ccavenue do
  let(:gateway) { Spree::Gateway::Ccavenue.create!(name: "Ccavenue", environment: 'test') }

  context "payment purchase" do
    let(:payment) do
      payment = FactoryBot.create(:payment, :payment_method => gateway, :amount => 10)
      allow(payment).to receive(:capture_events).and_return(double('capture_events', :create! => double('ee').as_null_object))
      payment
    end

    let(:provider) do
      provider = double('Provider')
      gateway.stub(:provider => provider)
      provider
    end

    it "succeeds" do
      allow(payment).to receive(:source).and_return(Spree::Ccavenue::Transaction.new(:auth_desc => 'Success'))
      expect(payment.purchase!).to be_true
    end

    it "fails" do
      allow(payment).to receive(:source).and_return(Spree::Ccavenue::Transaction.new(:auth_desc => 'Failure'))
      expect { payment.purchase! }.to raise_exception(Spree::Core::GatewayError)
    end
  end
end
