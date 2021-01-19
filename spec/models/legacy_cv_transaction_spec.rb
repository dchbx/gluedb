require 'rails_helper'

 describe Protocols::LegacyCv::LegacyCvTransaction do
  let(:policy) { FactoryGirl.create(:policy) }
  let(:transaction) { Protocols::LegacyCv::LegacyCvTransaction.new }

   it "builds with the proper attributes" do
    ["body", "submitted_at", "location"].each do |attribute|
      expect(transaction.class).to eq(Protocols::LegacyCv::LegacyCvTransaction)
    end
  end
end
