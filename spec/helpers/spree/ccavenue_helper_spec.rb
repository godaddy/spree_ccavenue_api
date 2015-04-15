module Spree
  describe CcavenueHelper, type: :helper do

    subject { helper.css_class_based_on_order_state(order).split(" ") }

    context "when state is 'confirm'" do

      let(:order) { double("order", state: "confirm") }

      it "has css class alpha" do
        expect(subject).to include "alpha"
      end

      it "has css class omega" do
        expect(subject).to include "omega"
      end

      it "has css class grid_24" do
        expect(subject).to include "grid_24"
      end

    end

    context "when state is not 'confirm'" do

      let(:order) { double("order", state: "NOT confirm") }

      it "has css class alpha" do
        expect(subject).to include "alpha"
      end

      it "has css class grid_16" do
        expect(subject).to include "grid_16"
      end

    end

  end
end
