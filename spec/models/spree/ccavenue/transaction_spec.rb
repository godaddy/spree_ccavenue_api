require 'spec_helper'

describe Spree::Ccavenue::Transaction do
  let(:successful_tran) { Spree::Ccavenue::Transaction.create! auth_desc: 'Success' }
  let(:failed_tran) { Spree::Ccavenue::Transaction.create! auth_desc: 'Failure' }
  let(:aborted_tran) { Spree::Ccavenue::Transaction.create! auth_desc: 'Aborted' }
  context "#success?" do
    it "returns true when transaction is successful" do
      expect(successful_tran.success?).to eq(true)
    end
  end

  context "#failed?" do
    it "returns true when transaction has failed" do
      expect(failed_tran.failed?).to eq(true)
    end
  end

  context "#aborted?" do
    it "returns true when transaction has been aborted" do
      expect(aborted_tran.aborted?).to eq(true)
    end
  end
end
