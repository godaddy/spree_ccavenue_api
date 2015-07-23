describe CcavenueApi::Response do

  let(:successful_http_payload) { { "status" => "0", "enc_response" => "1234" } }
  let(:failed_api_request_payload) { { "status" => "1", "enc_response" => "1234" } }
  let(:crypter) { CcavenueApi::Crypter.new('123') }

  describe "#failed_http_request" do
    it "returns a CcavenueApi::Response object" do
      expect(CcavenueApi::Response.failed_http_request(double, double)).to be_kind_of(CcavenueApi::Response)
    end
    it "the returned object indicates fail" do
      expect(CcavenueApi::Response.failed_http_request(double, double).successful?).to eq(false)
    end
  end
  describe "#successful_http_request" do
    before do
      allow_any_instance_of(CcavenueApi::Crypter).to receive(:decrypt).and_return(double('decrypted_response'))
      allow(ActiveSupport::JSON).to receive(:decode).and_return(double)
      allow(CcavenueApi::Response).to receive(:build_from_response).and_return({ request_successful: true})
    end
    it "returns a CcavenueApi::Response object" do
      expect(CcavenueApi::Response.successful_http_request(successful_http_payload, crypter)).to be_kind_of(CcavenueApi::Response)
    end
    context "with successful api response" do
      it "the returned object indicates success" do
        expect(CcavenueApi::Response.successful_http_request(successful_http_payload, crypter).successful?).to eq(true)
      end
    end
    context "with failed api response" do
      it "the returned object indicates success" do
        expect(CcavenueApi::Response.successful_http_request(failed_api_request_payload, crypter).successful?).to eq(false)
      end
    end
  end

  describe "#successful?" do
    let(:successful_args) { { :http_status => :success, :api_status => :success, :request_successful => true}}
    it "returns true when http_status and api_status and request_successful are valid" do
      expect(CcavenueApi::Response.new(successful_args).successful?).to eq(true)
    end
    it "returns false when http_status is false" do
      expect(CcavenueApi::Response.new(successful_args.merge(:http_status => :failed)).successful?).to eq(false)
    end
    it "returns false when api_status is false" do
      expect(CcavenueApi::Response.new(successful_args.merge(:api_status => :failed)).successful?).to eq(false)
    end
    it "returns false when request_successful is false or nil" do
      expect(CcavenueApi::Response.new(successful_args.merge(:request_successful => false)).successful?).to eq(false)
      expect(CcavenueApi::Response.new(successful_args.merge(:request_successful => nil)).successful?).to eq(false)
    end
  end
end
