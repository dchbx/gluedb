require "rails_helper"

RSpec.describe "edi_transaction_sets/show.html.erb" do
  let!(:person) { FactoryGirl.create(:person) }
  let(:subscriber) { double(person: person) }
  let!(:policy) { FactoryGirl.create(:policy) }
  let(:transmission) { double(id: 1) }
  let(:body) do
    double(
      read: "This is the body text being read."
    )
  end
  let(:edi_transaction_set) do 
    double(
      id: 1,
      st01: "1",
      st02: "2",
      st03: "3",
      bgn01: "1",
      bgn02: "2",
      bgn03: "3",
      bgn04: "4",
      bgn05: "5",
      bgn06: "6",
      bgn08: "8",
      transaction_kind: "fake_transaction",
      submitted_at: Date.today,
      ack_nak_processed_at: Date.today - 1.week,
      aasm_state: 'submitted',
      body: body,
      transmission_id: transmission.id,
      policy: policy,
      updated_at: Date.today
    )
  end

  before(:each) do
    allow(policy).to receive(:subscriber).and_return(subscriber)
    assign(:edi_transaction_set, edi_transaction_set)
  end

  it "should render the proper page elements" do 
    render :template => "edi_transaction_sets/show"
    expect(rendered).to match /EDI Transmission/
    expect(rendered).to match /Individual/
  end
end
