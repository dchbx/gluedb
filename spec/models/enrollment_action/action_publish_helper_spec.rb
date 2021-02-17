require "rails_helper"

describe EnrollmentAction::ActionPublishHelper, "told to swap premium totals from another event XML" do
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:source_premium_total) { "56.78" }
  let(:source_tot_res_amt) { "123.45" }
  let(:source_emp_res_amt) { "98.76" }
  let(:source_ivl_assistance_amount) { "34.21" }

  let(:source_event_xml) { <<-EVENTXML
  <enrollment xmlns="http://openhbx.org/api/terms/1.0">
  <policy>
  <enrollees>
    <enrollee>
      <member>
        <id><id>1</id></id>
      </member>
      <benefit>
        <premium_amount>111.11</premium_amount>
      </benefit>
    </enrollee>
    <enrollee>
      <member>
        <id><id>2</id></id>
      </member>
      <benefit>
        <premium_amount>222.22</premium_amount>
      </benefit>
    </enrollee>
  </enrollees>
  <enrollment>
  <individual_market>
    <applied_aptc_amount>#{source_ivl_assistance_amount}</applied_aptc_amount>
  </individual_market>
  <shop_market>
    <total_employer_responsible_amount>#{source_emp_res_amt}</total_employer_responsible_amount>
  </shop_market>
  <premium_total_amount>#{source_premium_total}</premium_total_amount>
  <total_responsible_amount>#{source_tot_res_amt}</total_responsible_amount>
  </enrollment>
  </policy>
  </enrollment>
  EVENTXML
  }
  let(:target_event_xml) { <<-EVENTXML
  <enrollment xmlns="http://openhbx.org/api/terms/1.0">
  <policy>
  <enrollees>
    <enrollee>
      <member>
        <id><id>1</id></id>
      </member>
      <benefit>
        <premium_amount>0.0</premium_amount>
      </benefit>
    </enrollee>
    <enrollee>
      <member>
        <id><id>3</id></id>
      </member>
      <benefit>
        <premium_amount>333.33</premium_amount>
      </benefit>
    </enrollee>
  </enrollees>
  <enrollment>
  <individual_market>
    <applied_aptc_amount>0.00</applied_aptc_amount>
  </individual_market>
  <shop_market>
    <total_employer_responsible_amount>0.00</total_employer_responsible_amount>
  </shop_market>
  <premium_total_amount>0.00</premium_total_amount>
  <total_responsible_amount>0.00</total_responsible_amount>
  </enrollment>
  </policy>
  </enrollment>
  EVENTXML
  }

  let(:action_publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(target_event_xml) }

  let(:transformed_target_xml) {
    action_publish_helper.replace_premium_totals(source_event_xml)
    Nokogiri::XML(action_publish_helper.to_xml)
  }

    let(:member_premium_xpath) {
      "//cv:policy/cv:enrollees/cv:enrollee/cv:member/cv:id/cv:id[contains(., '1')]/../../../cv:benefit/cv:premium_amount"
    }

    let(:dependent_premium_xpath) {
      "//cv:policy/cv:enrollees/cv:enrollee/cv:member/cv:id/cv:id[contains(., '3')]/../../../cv:benefit/cv:premium_amount"
    }

    let(:premium_total_xpath) {
      "//cv:policy/cv:enrollment/cv:premium_total_amount"
    }
    let(:tot_res_amount_xpath) {
      "//cv:policy/cv:enrollment/cv:total_responsible_amount"
    }

    let(:employer_contribution_xpath) {
      "//cv:policy/cv:enrollment/cv:shop_market/cv:total_employer_responsible_amount"
    }

    let(:ivl_assistance_xpath) {
      "//cv:policy/cv:enrollment/cv:individual_market/cv:applied_aptc_amount"
    }

    let(:first_member_premium_xml_node) { transformed_target_xml.xpath(member_premium_xpath, xml_namespace).first }
    let(:dependent_premium_xml_node) { transformed_target_xml.xpath(dependent_premium_xpath, xml_namespace).first }
    let(:target_xml_premium_total_node) { transformed_target_xml.xpath(premium_total_xpath, xml_namespace).first }
    let(:target_xml_tot_res_amount_node) { transformed_target_xml.xpath(tot_res_amount_xpath, xml_namespace).first }
    let(:target_xml_emp_res_node) { transformed_target_xml.xpath(employer_contribution_xpath, xml_namespace).first }
    let(:target_xml_ivl_assistance_node) { transformed_target_xml.xpath(ivl_assistance_xpath, xml_namespace).first }

    it "sets the premium_total_amount correctly" do
      expect(target_xml_premium_total_node.content).to eql(source_premium_total)
    end

    it "sets the total_responsible_amount correctly" do
      expect(target_xml_tot_res_amount_node.content).to eq(source_tot_res_amt)
    end

    it "sets the employer_responsible_amount correctly" do
      expect(target_xml_emp_res_node.content).to eq(source_emp_res_amt)
    end

    it "sets the ivl assistance amount correctly" do
      expect(target_xml_ivl_assistance_node.content).to eq(source_ivl_assistance_amount)
    end

    it "sets the replaced individual premium correctly" do
      expect(first_member_premium_xml_node.content).to eq("111.11")
    end

    it "does not replace the other individual premium" do
      expect(dependent_premium_xml_node.content).to eq("333.33")
    end
end

describe EnrollmentAction::ActionPublishHelper, "told to swap the qualifying event from another event XML" do
  let(:source_event_type) { "urn:dc0:terms:v1:qualifying_life_event#new_eligibility_member" }
  let(:source_event_date) { "20170309" }

  let(:source_event_xml) { <<-EVENTXML
  <enrollment xmlns="http://openhbx.org/api/terms/1.0">
  <policy>
  <eligibility_event>
  <event_kind>#{source_event_type}</event_kind>
  <event_date>#{source_event_date}</event_date>
  </eligibility_event>
  </policy>
  </enrollment>
  EVENTXML
  }
  let(:target_event_xml) { <<-EVENTXML
  <enrollment xmlns="http://openhbx.org/api/terms/1.0">
  <policy>
  <eligibility_event>
  <event_kind>urn:dc0:terms:v1:qualifying_life_event#new_hire</event_kind>
  <event_date>20140201</event_date>
  </eligibility_event>
  </policy>
  </enrollment>
  EVENTXML
  }

  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }

  let(:publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(target_event_xml) }

  let(:target_xml_doc) {
    publish_helper.swap_qualifying_event(source_event_xml)
    Nokogiri::XML(publish_helper.to_xml)
  }

  let(:qualifying_event_type_node) {
    target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:eligibility_event/cv:event_kind", xml_namespace).first
  }

  let(:qualifying_event_date_node) {
    target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:eligibility_event/cv:event_date", xml_namespace).first
  }

  it "sets the qualifying event type" do
    expect(qualifying_event_type_node.content).to eq(source_event_type)
  end

  it "sets the qualifying event date" do
    expect(qualifying_event_date_node.content).to eq(source_event_date)
  end
end

describe EnrollmentAction::ActionPublishHelper, "SHOP: recalculating premium totals after a dependent drop" do
  let(:primary_member_id) { "1000" }
  let(:secondary_member_id) { "1001" }
  let(:dropped_member_id) { "1002" }
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:premium_amount) { '100.00' }
  let(:total_employer_responsible_amount) { '185.00' }
  let(:dependent_drop_event) { <<-EVENTXML
    <enrollment xmlns="http://openhbx.org/api/terms/1.0">
      <policy>
        <enrollees>
          <enrollee>
            <member>
              <id>
                <id>urn:openhbx:hbx:dc0:resources:v1:person:hbx_id##{primary_member_id}</id>
              </id>
            </member>
            <benefit>
              <premium_amount>#{premium_amount}</premium_amount>
            </benefit>
          </enrollee>
          <enrollee>
            <member>
              <id>
                <id>urn:openhbx:hbx:dc0:resources:v1:person:hbx_id##{secondary_member_id}</id>
              </id>
            </member>
            <benefit>
              <premium_amount>#{premium_amount}</premium_amount>
            </benefit>
          </enrollee>
          <enrollee>
            <member>
              <id>
                <id>urn:openhbx:hbx:dc0:resources:v1:person:hbx_id##{dropped_member_id}</id>
              </id>
            </member>
            <benefit>
              <premium_amount>#{premium_amount}</premium_amount>
            </benefit>
          </enrollee>
        </enrollees>
      <enrollment>
        <shop_market>
          <total_employer_responsible_amount>#{total_employer_responsible_amount}</total_employer_responsible_amount>
        </shop_market>
        <premium_total_amount>300.00</premium_total_amount>
        <total_responsible_amount>125.00</total_responsible_amount>
      </enrollment>
    </policy>
  </enrollment>
  EVENTXML
  }

  let(:publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(dependent_drop_event) }

  let(:target_xml_doc) {
    publish_helper.recalculate_premium_totals_excluding_dropped_dependents([primary_member_id, secondary_member_id])
    Nokogiri::XML(publish_helper.to_xml)
  }

  let(:premium_total_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:premium_total_amount", xml_namespace).first }
  let(:total_responsible_amount_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:total_responsible_amount", xml_namespace).first }
  let(:total_employer_responsible_amount_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:shop_market/cv:total_employer_responsible_amount", xml_namespace).first }

  it "recalculates the correct total excluding the dropped member" do
    expect(premium_total_xpath.content).to eq("200.0")
  end

  it "recalculates the correct total_responsible_amount" do
    expect(total_responsible_amount_xpath.content).to eq("76.67")
  end

  it "leaves the total employer responsible amount unchanged" do
    expect(total_employer_responsible_amount_xpath.content).to eq("123.33")
  end

  it "is shop" do
    expect(publish_helper.is_shop?).to be_truthy
  end

  context "with an original employer contribution greater than the adjusted total" do
    let(:total_employer_responsible_amount) { '300.00' }
    it "recalculates the contribution to be no greater than the total premium" do
      expect(total_employer_responsible_amount_xpath.content).to eq("200.0")
    end
    it "sets the correct total_responsible_amount value" do
      expect(total_responsible_amount_xpath.content).to eq('0.0')
    end
  end
end


describe EnrollmentAction::ActionPublishHelper, "SHOP: recalculating premium totals after a dependent drop and total employer contribution less than premium" do
  let(:primary_member_id) { "1000" }
  let(:secondary_member_id) { "1001" }
  let(:dropped_member_id) { "1002" }
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:premium_amount1) { '439.99' }
  let(:premium_amount2) { '462.57' }
  let(:total_employer_responsible_amount) { '676.92' }
  let(:premium_total_amount) { '902.56' }
  let(:dependent_drop_event) { <<-EVENTXML
    <enrollment xmlns="http://openhbx.org/api/terms/1.0">
      <policy>
        <enrollees>
          <enrollee>
            <member>
              <id>
                <id>urn:openhbx:hbx:dc0:resources:v1:person:hbx_id##{primary_member_id}</id>
              </id>
            </member>
            <benefit>
              <premium_amount>#{premium_amount1}</premium_amount>
            </benefit>
          </enrollee>
          <enrollee>
            <member>
              <id>
                <id>urn:openhbx:hbx:dc0:resources:v1:person:hbx_id##{dropped_member_id}</id>
              </id>
            </member>
            <benefit>
              <premium_amount>#{premium_amount2}</premium_amount>
            </benefit>
          </enrollee>
        </enrollees>
      <enrollment>
        <shop_market>
          <total_employer_responsible_amount>#{total_employer_responsible_amount}</total_employer_responsible_amount>
        </shop_market>
         <premium_total_amount>#{premium_total_amount}</premium_total_amount>
        <total_responsible_amount>125.00</total_responsible_amount>
      </enrollment>
    </policy>
  </enrollment>
  EVENTXML
  }

  let(:publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(dependent_drop_event) }

  let(:target_xml_doc) {
    publish_helper.recalculate_premium_totals_excluding_dropped_dependents([primary_member_id])
    Nokogiri::XML(publish_helper.to_xml)
  }

  let(:premium_total_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:premium_total_amount", xml_namespace).first }
  let(:total_responsible_amount_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:total_responsible_amount", xml_namespace).first }
  let(:total_employer_responsible_amount_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:shop_market/cv:total_employer_responsible_amount", xml_namespace).first }

  it "recalculates the correct total excluding the dropped member" do
    expect(premium_total_xpath.content).to eq("439.99")
  end

  it "recalculates the correct total_responsible_amount" do
    expect(total_responsible_amount_xpath.content).to eq("110.0")
  end

  it "leaves the total employer responsible amount unchanged" do
    expect(total_employer_responsible_amount_xpath.content).to eq("329.99")
  end

  it "is shop" do
    expect(publish_helper.is_shop?).to be_truthy
  end
end

describe EnrollmentAction::ActionPublishHelper, "SHOP: altering tiers after a dependent drop" do
  let(:primary_member_id) { "1000" }
  let(:secondary_member_id) { "1001" }
  let(:dropped_member_id) { "1002" }
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:dependent_drop_event) { <<-EVENTXML
    <enrollment xmlns="http://openhbx.org/api/terms/1.0">
      <policy>
      <enrollment>
        <shop_market>
          <composite_rating_tier_name>#{old_rating_tier}</composite_rating_tier_name>
        </shop_market>
        <premium_total_amount>300.00</premium_total_amount>
        <total_responsible_amount>125.00</total_responsible_amount>
      </enrollment>
    </policy>
  </enrollment>
  EVENTXML
  }

  let(:new_purchase_xml) { <<-EVENTXML
    <enrollment xmlns="http://openhbx.org/api/terms/1.0">
      <policy>
      <enrollment>
        <shop_market>
          <composite_rating_tier_name>#{new_rating_tier}</composite_rating_tier_name>
        </shop_market>
        <premium_total_amount>300.00</premium_total_amount>
        <total_responsible_amount>125.00</total_responsible_amount>
      </enrollment>
    </policy>
  </enrollment>
  EVENTXML
  }

  let(:old_rating_tier) { "OLD RATING TIER" }
  let(:new_rating_tier) { "NEW RATING TIER" }

  let(:publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(dependent_drop_event) }

  let(:target_xml_doc) {
    publish_helper.take_rating_tier_from(new_purchase_xml)
    Nokogiri::XML(publish_helper.to_xml)
  }

  let(:rating_tier_xpath) { target_xml_doc.xpath("//cv:shop_market/cv:composite_rating_tier_name", xml_namespace).first }

  it "assigns the new rating tier" do
    expect(rating_tier_xpath.content).to eq new_rating_tier
  end

  it "is shop" do
    expect(publish_helper.is_shop?).to be_truthy
  end

end

describe EnrollmentAction::ActionPublishHelper, "IVL: recalculating premium totals after a dependent drop" do
  let(:primary_member_id) { "1000" }
  let(:secondary_member_id) { "1001" }
  let(:dropped_member_id) { "1002" }
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:premium_amount) { '100.00' }
  let(:applied_aptc_amount) { '150.00' }

  let(:dependent_drop_event) { <<-EVENTXML
    <enrollment xmlns="http://openhbx.org/api/terms/1.0">
      <policy>
        <enrollees>
          <enrollee>
            <member>
              <id>
                <id>urn:openhbx:hbx:dc0:resources:v1:person:hbx_id##{primary_member_id}</id>
              </id>
            </member>
            <benefit>
              <premium_amount>#{premium_amount}</premium_amount>
            </benefit>
          </enrollee>
          <enrollee>
            <member>
              <id>
                <id>urn:openhbx:hbx:dc0:resources:v1:person:hbx_id##{secondary_member_id}</id>
              </id>
            </member>
            <benefit>
              <premium_amount>#{premium_amount}</premium_amount>
            </benefit>
          </enrollee>
          <enrollee>
            <member>
              <id>
                <id>urn:openhbx:hbx:dc0:resources:v1:person:hbx_id##{dropped_member_id}</id>
              </id>
            </member>
            <benefit>
              <premium_amount>#{premium_amount}</premium_amount>
            </benefit>
          </enrollee>
        </enrollees>
      <enrollment>
        <individual_market>
          <is_carrier_to_bill>true</is_carrier_to_bill>
          <applied_aptc_amount>#{applied_aptc_amount}</applied_aptc_amount>
        </individual_market>
        <premium_total_amount>300.00</premium_total_amount>
        <total_responsible_amount>150.00</total_responsible_amount>
      </enrollment>
    </policy>
  </enrollment>
  EVENTXML
  }

  let(:publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(dependent_drop_event) }

  let(:target_xml_doc) {
    publish_helper.recalculate_premium_totals_excluding_dropped_dependents([primary_member_id, secondary_member_id])
    Nokogiri::XML(publish_helper.to_xml)
  }

  let(:premium_total_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:premium_total_amount", xml_namespace).first }
  let(:total_responsible_amount_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:total_responsible_amount", xml_namespace).first }
  let(:applied_aptc_amount_xpath) { target_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollment/cv:individual_market/cv:applied_aptc_amount", xml_namespace).first }

  it "recalculates the correct total excluding the dropped member" do
    expect(premium_total_xpath.content).to eq("200.0")
  end

  it "recalculates the correct total_responsible_amount" do
    expect(total_responsible_amount_xpath.content).to eq("50.0")
  end

  it "is not shop" do
    expect(publish_helper.is_shop?).to be_falsey
  end

  context "with an original aptc amount greater than the adjusted total" do
    let(:applied_aptc_amount) { '250.00' }
    it "recalculates the contribution to be no greater than the total premium" do
      expect(applied_aptc_amount_xpath.content).to eq("200.0")
    end
    it "sets the correct total_responsible_amount value" do
      expect(total_responsible_amount_xpath.content).to eq('0.0')
    end
  end
end

describe EnrollmentAction::ActionPublishHelper, "told to assign an assistance effective date, when no node exists" do
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:source_premium_total) { "56.78" }
  let(:source_tot_res_amt) { "123.45" }
  let(:source_emp_res_amt) { "98.76" }
  let(:source_ivl_assistance_amount) { "34.21" }
  let(:assistance_effective_date) { Date.new(2008, 10, 24) }

  let(:target_event_xml) { <<-EVENTXML
  <enrollment xmlns="http://openhbx.org/api/terms/1.0">
  <policy>
  <enrollees>
    <enrollee>
      <member>
        <id><id>1</id></id>
      </member>
      <benefit>
        <premium_amount>111.11</premium_amount>
      </benefit>
    </enrollee>
    <enrollee>
      <member>
        <id><id>2</id></id>
      </member>
      <benefit>
        <premium_amount>222.22</premium_amount>
      </benefit>
    </enrollee>
  </enrollees>
  <enrollment>
  <individual_market>
    <applied_aptc_amount>#{source_ivl_assistance_amount}</applied_aptc_amount>
  </individual_market>
  <shop_market>
    <total_employer_responsible_amount>#{source_emp_res_amt}</total_employer_responsible_amount>
  </shop_market>
  <premium_total_amount>#{source_premium_total}</premium_total_amount>
  <total_responsible_amount>#{source_tot_res_amt}</total_responsible_amount>
  </enrollment>
  </policy>
  </enrollment>
  EVENTXML
  }

  let(:transformed_target_xml) {
    action_publish_helper.assign_assistance_date(assistance_effective_date)
    Nokogiri::XML(action_publish_helper.to_xml)
  }
  let(:assistance_date_result) { transformed_target_xml.xpath("//cv:policy/cv:enrollment/cv:individual_market/cv:assistance_effective_date", xml_namespace).first }
  let(:action_publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(target_event_xml) }

  it "sets the correct date" do
    expect(assistance_date_result.content).to eq "20081024"
  end
end

describe EnrollmentAction::ActionPublishHelper, "told to assign an assistance effective date, when node already exists" do
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:source_premium_total) { "56.78" }
  let(:source_tot_res_amt) { "123.45" }
  let(:source_emp_res_amt) { "98.76" }
  let(:source_ivl_assistance_amount) { "34.21" }
  let(:assistance_effective_date) { Date.new(2008, 10, 24) }

  let(:target_event_xml) { <<-EVENTXML
  <enrollment xmlns="http://openhbx.org/api/terms/1.0">
  <policy>
  <enrollees>
    <enrollee>
      <member>
        <id><id>1</id></id>
      </member>
      <benefit>
        <premium_amount>111.11</premium_amount>
      </benefit>
    </enrollee>
    <enrollee>
      <member>
        <id><id>2</id></id>
      </member>
      <benefit>
        <premium_amount>222.22</premium_amount>
      </benefit>
    </enrollee>
  </enrollees>
  <enrollment>
  <individual_market>
    <applied_aptc_amount>#{source_ivl_assistance_amount}</applied_aptc_amount>
    <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
  </individual_market>
  <shop_market>
    <total_employer_responsible_amount>#{source_emp_res_amt}</total_employer_responsible_amount>
  </shop_market>
  <premium_total_amount>#{source_premium_total}</premium_total_amount>
  <total_responsible_amount>#{source_tot_res_amt}</total_responsible_amount>
  </enrollment>
  </policy>
  </enrollment>
  EVENTXML
  }

  let(:transformed_target_xml) {
    action_publish_helper.assign_assistance_date(assistance_effective_date)
    Nokogiri::XML(action_publish_helper.to_xml)
  }
  let(:assistance_date_result) { transformed_target_xml.xpath("//cv:policy/cv:enrollment/cv:individual_market/cv:assistance_effective_date", xml_namespace).first }
  let(:action_publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(target_event_xml) }

  it "sets the correct date" do
    expect(assistance_date_result.content).to eq "20081024"
  end
end

RSpec.shared_examples "a publish helper adding employer contact and office location information" do
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }

  let(:employer_id) { "some_employer_id" }

  let(:publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(event_xml) }

  let(:transformed_target_xml) { Nokogiri::XML(publish_helper.to_xml) }

  let(:employer) { instance_double(Employer) }
  let(:controller) { instance_double(ApplicationController) }

  before :each do
    allow(Employer).to receive(:where).with({:hbx_id => employer_id}).and_return([employer])
    allow(ApplicationController).to receive(:new).and_return(controller)
  end

  it "includes the employer contacts" do
    expect(
      transformed_target_xml.
        xpath("//cv:shop_market/cv:employer_link/cv:contacts", xml_namespace).
        count
    ).to eq 1
  end

  it "includes the employer office locations" do
    expect(
      transformed_target_xml.
        xpath("//cv:shop_market/cv:employer_link/cv:office_locations", xml_namespace).
        count
    ).to eq 1
  end

  it "includes employer contacts before the office locations" do
    ec_node = transformed_target_xml.
                xpath("//cv:shop_market/cv:employer_link/cv:contacts", xml_namespace).first
    ol_node = transformed_target_xml.
                xpath("//cv:shop_market/cv:employer_link/cv:office_locations", xml_namespace).first
    ol_index = ol_node.parent.children.index(ol_node)
    ec_index = ol_node.parent.children.index(ec_node)
    expect(ec_index < ol_index).to be_truthy
  end
end

describe EnrollmentAction::ActionPublishHelper, "given an event that has no employer contact info" do

  let(:event_xml) do
    <<-EVENTXML
      <enrollment xmlns="http://openhbx.org/api/terms/1.0">
        <policy>
        <enrollment>
          <shop_market>
            <employer_link>
              <id>
                <id>urn:kjlsdfke##{employer_id}</id>
              </id>
              <office_locations/>
            </employer_link>
          </shop_market>
        </enrollment>
      </policy>
    </enrollment>
    EVENTXML
  end

  let(:contacts_xml) { "<contacts/>"}

  before :each do
    allow(controller).to receive(:render_to_string).with(
      :layout =>  nil,
      :partial => "enrollment_events/employer_with_contacts",
      :object => employer,
      :format => :xml
    ).and_return(contacts_xml)
  end

  it_behaves_like "a publish helper adding employer contact and office location information"
end

describe EnrollmentAction::ActionPublishHelper, "given an event that has no office locations" do

  let(:event_xml) do
    <<-EVENTXML
      <enrollment xmlns="http://openhbx.org/api/terms/1.0">
        <policy>
        <enrollment>
          <shop_market>
            <employer_link>
              <id>
                <id>urn:kjlsdfke##{employer_id}</id>
              </id>
              <contacts/>
            </employer_link>
          </shop_market>
        </enrollment>
      </policy>
    </enrollment>
    EVENTXML
  end

  let(:office_locations_xml) { "<office_locations/>"}
  
  before :each do
    allow(controller).to receive(:render_to_string).with(
      :layout => nil,
      :partial => "enrollment_events/employer_with_office_locations",
      :object => employer,
      :format => :xml
    ).and_return(office_locations_xml)
  end

  it_behaves_like "a publish helper adding employer contact and office location information"
end

describe EnrollmentAction::ActionPublishHelper, "given an event that has no employer contact info or office locations" do

  let(:employer_id) { "some_employer_id" }

  let(:event_xml) do
    <<-EVENTXML
      <enrollment xmlns="http://openhbx.org/api/terms/1.0">
        <policy>
        <enrollment>
          <shop_market>
            <employer_link>
              <id>
                <id>urn:kjlsdfke##{employer_id}</id>
              </id>
            </employer_link>
          </shop_market>
        </enrollment>
      </policy>
    </enrollment>
    EVENTXML
  end

  let(:contacts_xml) { "<contacts/>"}
  let(:office_locations_xml) { "<office_locations/>"}
  
  before :each do
    allow(controller).to receive(:render_to_string).with(
      :layout => nil,
      :partial => "enrollment_events/employer_with_contacts", :object => employer,
      :format => :xml
    ).and_return(contacts_xml)
    allow(controller).to receive(:render_to_string).with(
      :layout => nil,
      :partial => "enrollment_events/employer_with_office_locations", :object => employer,
      :format => :xml
    ).and_return(office_locations_xml)
  end

  it_behaves_like "a publish helper adding employer contact and office location information"
end

describe EnrollmentAction::ActionPublishHelper, "told to set affected and enrolles end dates, when member node exists" do
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:end_date) { Date.new(2019,11,30) }

  let(:member_end_hash) { {"1"=> end_date, "2" => end_date } }
  let(:source_event_xml) { <<-EVENTXML
  <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
    <affected_members>
      <affected_member>
        <member>
          <id><id>1</id></id>
        </member>
        <benefit>
          <premium_amount>465.13</premium_amount>
          <begin_date>2019101</begin_date>
           <end_date>2019121}</end_date>
        </benefit>
      </affected_member>
      <affected_member>
        <member>
          <id><id>2</id></id>
        </member>
        <benefit>
          <premium_amount>465.13</premium_amount>
          <begin_date>2019101</begin_date>
           <end_date>2019121</end_date>
        </benefit>
      </affected_member>
    </affected_members>
  <enrollment xmlns="http://openhbx.org/api/terms/1.0">
  <policy>
  <enrollees>
    <enrollee>
      <member>
        <id><id>1</id></id>
      </member>
      <benefit>
        <premium_amount>111.11</premium_amount>
        <begin_date>2019101</begin_date>
        <end_date>2019121</end_date>
      </benefit>
    </enrollee>
    <enrollee>
      <member>
        <id><id>2</id></id>
      </member>
      <benefit>
        <premium_amount>222.22</premium_amount>
         <begin_date>2019101</begin_date>
        <end_date>2019121</end_date>
      </benefit>
    </enrollee>
  </enrollees>
  <enrollment>
  <individual_market>
    <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
  </individual_market>
  <shop_market>
    <total_employer_responsible_amount>98.76</total_employer_responsible_amount>
  </shop_market>
  <premium_total_amount>56.78</premium_total_amount>
  <total_responsible_amount>123.45</total_responsible_amount>
  </enrollment>
  </policy>
  </enrollment>
  </enrollment_event_body>
  EVENTXML
  }

  let(:transformed_target_xml) {
    action_publish_helper.set_member_end_date(member_end_hash)
    Nokogiri::XML(action_publish_helper.to_xml)
  }
  let(:action_publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(source_event_xml) }

  it "sets the correct end date" do
    transformed_target_xml.xpath("//cv:enrollment_event_body/cv:affected_members/cv:affected_member", xml_namespace).each do |node|
      node.xpath("cv:benefit/cv:end_date", xml_namespace).each do |d_node|
        expect(d_node.content).to eq "20191130"
      end
    end

    transformed_target_xml.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", xml_namespace).each do |node|
      node.xpath("cv:benefit/cv:end_date", xml_namespace).each do |d_node|
        expect(d_node.content).to eq "20191130"
      end
    end
  end
end

describe EnrollmentAction::ActionPublishHelper, "told to remove enrolles, when unmatched member node exists" do
  let(:xml_namespace) { { :cv => "http://openhbx.org/api/terms/1.0" } }
  let(:keep_member_ids) {["1"] }
  let(:source_event_xml) { <<-EVENTXML
  <enrollment_event_body xmlns="http://openhbx.org/api/terms/1.0">
    <affected_members>
      <affected_member>
        <member>
          <id><id>1</id></id>
        </member>
        <benefit>
          <premium_amount>465.13</premium_amount>
          <begin_date>2019101</begin_date>
           <end_date>2019121}</end_date>
        </benefit>
      </affected_member>
      <affected_member>
        <member>
          <id><id>2</id></id>
        </member>
        <benefit>
          <premium_amount>465.13</premium_amount>
          <begin_date>2019101</begin_date>
           <end_date>2019121</end_date>
        </benefit>
      </affected_member>
    </affected_members>
  <enrollment xmlns="http://openhbx.org/api/terms/1.0">
  <policy>
  <enrollees>
    <enrollee>
      <member>
        <id><id>1</id></id>
      </member>
      <benefit>
        <premium_amount>111.11</premium_amount>
        <begin_date>2019101</begin_date>
        <end_date>2019121</end_date>
      </benefit>
    </enrollee>
    <enrollee>
      <member>
        <id><id>2</id></id>
      </member>
      <benefit>
        <premium_amount>222.22</premium_amount>
         <begin_date>2019101</begin_date>
        <end_date>2019121</end_date>
      </benefit>
    </enrollee>
  </enrollees>
  <enrollment>
  <individual_market>
    <assistance_effective_date>TOTALLY BOGUS</assistance_effective_date>
  </individual_market>
  <shop_market>
    <total_employer_responsible_amount>98.76</total_employer_responsible_amount>
  </shop_market>
  <premium_total_amount>56.78</premium_total_amount>
  <total_responsible_amount>123.45</total_responsible_amount>
  </enrollment>
  </policy>
  </enrollment>
  </enrollment_event_body>
  EVENTXML
  }
  let(:transformed_target_xml) {
    action_publish_helper.filter_enrollee_members(keep_member_ids)
    Nokogiri::XML(action_publish_helper.to_xml)
  }
  let(:action_publish_helper) { ::EnrollmentAction::ActionPublishHelper.new(source_event_xml) }

  it "should remove member node" do
    expect(transformed_target_xml.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", xml_namespace).count).to eq 1
    expect(transformed_target_xml.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", xml_namespace).detect {|node| node.xpath("cv:member/cv:id/cv:id", xml_namespace).text == "2" }.present?).to eq false
  end
end
