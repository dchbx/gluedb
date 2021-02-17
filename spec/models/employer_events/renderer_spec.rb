require "rails_helper"

describe EmployerEvents::Renderer, "given an xml, from which it selects carrier plan years" do
  let(:event_time) { double }

  let(:carrier) { instance_double(Carrier, :hbx_carrier_id => hbx_carrier_id) }

  let(:source_document) do
		<<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>20151201</plan_year_start>
				<plan_year_end>20161130</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
		XMLCODE
  end

  let(:employer_event) { instance_double(EmployerEvent, {:event_time => event_time, :resource_body => source_document}) }

  subject do
     EmployerEvents::Renderer.new(employer_event)
  end

  let(:carrier_plan_years) { subject.carrier_plan_years(carrier) }

  describe "with plan years for the specified carrier" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }

    it "finds plan years for the carrier" do
      expect(carrier_plan_years).not_to be_empty
    end

    it "has the correct element in scope" do
      element_name = carrier_plan_years.to_a.map(&:name)
    end
  end

  describe "with no plan years for the specified carrier" do
    let(:hbx_carrier_id) { "A DIFFERENT CARRIER ID" }

    it "finds plan years for the carrier" do
      expect(carrier_plan_years).to be_empty
    end
  end
end

describe EmployerEvents::Renderer, "given an xml, with an event type of benefit_coverage_renewal_carrier_dropped" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(EmployerEvent, {:event_time => event_time, :event_name => EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(Carrier, :hbx_carrier_id => hbx_carrier_id) }

  let(:plan_year_end) { plan_year_start + 1.year - 1.day }

  let(:source_document) do
		<<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{plan_year_start.strftime("%Y%m%d")}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime("%Y%m%d")}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
		XMLCODE
  end

  subject do
     EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, in the future" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today + 1.day } 

    it "is an invalid carrier drop event" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_truthy
    end

    it "is not an invalid renewal event" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, in the past" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.day } 

    it "is NOT an invalid carrier drop event" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "is not an invalid renewal event" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe EmployerEvents::Renderer, "given an xml, with an event type of benefit_coverage_renewal_application_eligible" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(EmployerEvent, {:event_time => event_time, :event_name => EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(Carrier, :hbx_carrier_id => hbx_carrier_id) }

  let(:plan_year_end) { plan_year_start + 1.year - 1.day }

  let(:source_document) do
		<<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{plan_year_start.strftime("%Y%m%d")}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime("%Y%m%d")}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
		XMLCODE
  end

  subject do
     EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, in the future" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today + 1.day } 

    it "is NOT an invalid carrier drop event" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_false
    end

    it "is not an invalid renewal event" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, in the past" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.day } 

    it "is an invalid renewal event" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_truthy
    end

    it "is NOT an invalid carrier drop event" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_false
    end
  end
end

describe EmployerEvents::Renderer, "given an xml" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(EmployerEvent, {:event_time => event_time, :event_name => EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(Carrier, :hbx_carrier_id => hbx_carrier_id) }

  let(:plan_year_end) { plan_year_start + 1.year - 1.day }

  let(:source_document) do
		<<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{plan_year_start.strftime("%Y%m%d")}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime("%Y%m%d")}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
		XMLCODE
  end

  subject do
     EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, which starts in the future" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today + 1.day } 

    it "has a current or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_true
    end
  end

  describe "with plan years for the specified carrier, which starts today" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today } 

    it "has a current or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_true
    end
  end

  describe "with plan years for the specified carrier, which ends in the future" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.year + 2.days } 
    let(:plan_year_end) { Date.today + 1.day } 

    it "has a current or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_true
    end
  end

  describe "with plan years for the specified carrier, which ends today" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.year + 1.day } 
    let(:plan_year_end) { Date.today } 

    it "has a current plan or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_true
    end
  end

  describe "with plan years for the specified carrier, which ends in the past" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.year } 
    let(:plan_year_end) { Date.today - 1.day } 

    it "has no current plan or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_false
    end
  end

  describe "with plan years for a different carrier, which starts in the future" do
    let(:hbx_carrier_id) { "SOME OTHER CARRIER ID" }
    let(:plan_year_start) { Date.today + 1.day } 

    it "has no current or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_false
    end
  end
end

describe EmployerEvents::Renderer, "given an plan year cancelation xml, with an event type of benefit_coverage_renewal_carrier_dropped" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(EmployerEvent, {:event_time => event_time, :event_name => EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(Carrier, :hbx_carrier_id => hbx_carrier_id) }

  let(:source_document) do
    <<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{plan_year_start.strftime("%Y%m%d")}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime("%Y%m%d")}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
    XMLCODE
  end

  subject do
    EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, with plan year start date == end date" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today.beginning_of_month }
    let(:plan_year_end) { Date.today.beginning_of_month }

    it "should return true for carrier drop event with canceled plan year" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_truthy
    end

    it "should return false if has canceled plan year " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false if has canceled plan year" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false if has canceled plan year" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, drop event with future plan year" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }

    let(:plan_year_start) {  Date.today.next_month.beginning_of_month }
    let(:plan_year_end) {  plan_year_start + 1.year - 1.day }


    it "should return false for carrier drop event without canceled plan year" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_falsey
    end

    it "should return true " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_truthy
    end

    it "should return true" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_truthy
    end

    it "should return false" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe EmployerEvents::Renderer, "given an termianation xml, with an nonpayment/voltunary termination event" do
  let(:event_time) { double }
  let(:carrier) { instance_double(Carrier, :hbx_carrier_id => hbx_carrier_id) }

  let(:source_document) do
    <<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{plan_year_start.strftime("%Y%m%d")}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime("%Y%m%d")}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
    XMLCODE
  end



  describe "with plan years for the specified carrier, with benefit_coverage_period_terminated_voluntary event" do

    let(:employer_event) { instance_double(EmployerEvent, {:event_time => event_time, :event_name => "benefit_coverage_period_terminated_voluntary", :resource_body => source_document}) }

    subject do
      EmployerEvents::Renderer.new(employer_event)
    end

    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today.beginning_of_month - 10.month }
    let(:plan_year_end) {  (plan_year_start + 8.month).end_of_month }

    it "should return true if terminated plan year present" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_truthy
    end

    it "should return false " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, with benefit_coverage_period_terminated_nonpayment event" do

    let(:employer_event) { instance_double(EmployerEvent, {:event_time => event_time, :event_name => "benefit_coverage_period_terminated_nonpayment", :resource_body => source_document}) }

    subject do
      EmployerEvents::Renderer.new(employer_event)
    end

    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today.beginning_of_month - 10.month }
    let(:plan_year_end) {  (plan_year_start + 8.month).end_of_month }

    it "should return true if terminated plan year present" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_truthy
    end

    it "should return false " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe EmployerEvents::Renderer, "given an mid year plan year change, with an event type of benefit_coverage_initial_application_eligible" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(EmployerEvent, {:event_time => event_time, :event_name => EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME, :resource_body => source_document}) }

  let(:carrier) { instance_double(Carrier, :hbx_carrier_id => hbx_carrier_id) }
  let(:other_carrier) { instance_double(Carrier, :hbx_carrier_id => hbx_carrier_id2) }

  let(:source_document) do
    <<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{future_term_plan_year_start.strftime("%Y%m%d")}</plan_year_start>
				<plan_year_end>#{future_term_plan_year_end.strftime("%Y%m%d")}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
              <elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>OTHER CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>

      <plan_year>
				<plan_year_start>#{plan_year_start.strftime("%Y%m%d")}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime("%Y%m%d")}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
    XMLCODE
  end

  subject do
    EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, with plan year start date == end date" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:hbx_carrier_id2) { "OTHER CARRIER ID" }

    let(:future_term_plan_year_start) { Date.today.prev_month.beginning_of_month }
    let(:future_term_plan_year_end) { Date.today.end_of_month }
    let(:plan_year_start) { Date.today.next_month.beginning_of_month }
    let(:plan_year_end) {  plan_year_start + 1.year - 1.day }

    it "should return true for carrier in the future active plan year" do
      expect(subject.mid_cycle_plan_year?(carrier)).to be_truthy
    end

    it "should return false for carrier in the past active plan year" do
      expect(subject.mid_cycle_plan_year?(other_carrier)).to be_falsey
    end
  end
end