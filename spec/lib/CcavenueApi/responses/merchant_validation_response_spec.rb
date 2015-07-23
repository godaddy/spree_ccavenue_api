describe CcavenueApi::Responses::MerchantValidationResponse do

  subject { CcavenueApi::Responses::MerchantValidationResponse }

  let(:expected_error_code) { CcavenueApi::Responses::MerchantValidationResponse::MERCHANT_CREDS_VALID_ERROR_CODE }

  # decrypted_responses
  let(:success_merchant_validation_response) { { "status" => 1, "error_code" => expected_error_code } }
  let(:bad_merchant_validation_response_1) { { "status" => 0 } }
  let(:bad_merchant_validation_response_2) { { "status" => nil } }
  let(:bad_merchant_validation_response_3) { { "status" => 1, "error_code" => '123' } }

  describe "#build_from_response" do
    it "parses successful merchant_validation response properly" do
      expect(subject.build_from_response(success_merchant_validation_response)).to eq({ request_successful: true })
    end
    it "parses a bad merchant validation response with order status of 0 properly" do
      expect(subject.build_from_response(bad_merchant_validation_response_1)).to include({ :request_successful => false,
                                                                                         :reason => Spree.t("ccavenue.unexpected_api_status", { status: 0 })})
    end
    it "parses a bad merchant validation response with invalid order status properly" do
      expect(subject.build_from_response(bad_merchant_validation_response_2)).to include({ :api_status => :failed,
                                                                                           :reason => Spree.t("ccavenue.api_response_parse_failed") })
    end
    it "parses a bad merchant validation response with unexpected error_code properly" do
      expect(subject.build_from_response(bad_merchant_validation_response_3)).to include({ :request_successful => false,
                                                                                           :reason => Spree.t("ccavenue.invalid_api_error_code", {error_code: '123'})})
    end
  end

  describe "#successful?" do
    let(:successful_args) { { http_status: :success, api_status: :success, request_successful: true } }
    context "when some error" do
      it "returns false when http_status is failed" do
        expect(subject.new(successful_args.merge({ http_status: :failed })).successful?).to be(false)
      end
      it "returns false when api_status is failed" do
        expect(subject.new(successful_args.merge({ api_status: :failed })).successful?).to be(false)
      end
      it "returns false when status_count is 0" do
        expect(subject.new(successful_args.merge({ request_successful: false })).successful?).to be(false)
      end
    end
    context "when no error" do
      it "returns true" do
        expect(subject.new(successful_args).successful?).to be(true)
      end
    end
  end

end

