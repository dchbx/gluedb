# Generates Carrier Audits and Transforms

class TransformSimpleEdiFileSet
  include ::Handlers::EnrollmentEventXmlHelper

  XML_NS = { "cv" => "http://openhbx.org/api/terms/1.0" }

  def initialize(out_path)
    @out_path = out_path
  end

  def transform(xml_string)
    enrollment_event_xml = Nokogiri::XML(xml_string)
    edi_builder = EdiCodec::X12::BenefitEnrollment.new(xml_string)
    x12_xml = edi_builder.call.to_xml
    publish_to_file(enrollment_event_xml, x12_xml)
  end

  def publish_to_file(enrollment_event_xml, x12_payload)
    file_name = determine_file_name(enrollment_event_xml)
    File.open(File.join(@out_path, file_name), 'w') do |f|
      f.write(x12_payload)
    end
  end

  def find_carrier_abbreviation(enrollment_event_xml)
    hios_id = enrollment_event_xml.xpath("//cv:enrollment/cv:plan/cv:id/cv:id", XML_NS).first.content.strip.split("#").last
    active_year = enrollment_event_xml.xpath("//cv:enrollment/cv:plan/cv:active_year", XML_NS).first.content.strip
    found_plan = Caches::CustomCache.lookup(Plan, :cv2_hios_active_year_plan_cache, [active_year.to_i, hios_id]) do
     Plan.where(:hios_plan_id => hios_id, :year => active_year.to_i).first
    end
    found_carrier = Caches::CustomCache.lookup(Carrier, :cv2_carrier_cache, found_plan.carrier_id) { found_plan.carrier } 
    found_carrier.abbrev.upcase
  end

  def determine_file_name(enrollment_event_xml)
    market_identifier = shop_market?(enrollment_event_xml) ? "S" : "I"
    carrier_identifier = find_carrier_abbreviation(enrollment_event_xml)
    category_identifier = "_A_F_"
    "834_" + transaction_id(enrollment_event_xml) + "_" + carrier_identifier + category_identifier + market_identifier + "_1.xml"
  end

  protected

  def transaction_id(enrollment_event_xml)
    enrollment_event_xml.xpath("//cv:enrollment_event_body/cv:transaction_id", XML_NS).first.content.strip
  end

  def shop_market?(enrollment_event_xml)
    enrollment_event_xml.xpath("//cv:policy/cv:enrollment/cv:shop_market", XML_NS).any?
  end
end

class GenerateAudits
  def pull_policies(market,cutoff_date,carrier_abbrev)
    carrier_ids = Carrier.where(:abbrev => carrier_abbrev).map(&:id)
    plan_ids = Plan.where(:carrier_id => {"$in" => carrier_ids}).map(&:id)
    active_start = find_active_start(market,cutoff_date)
    active_end = find_active_end(cutoff_date)
    employer_ids = get_employer_ids(active_start,active_end,market)
    eligible_policies = Policy.where({:enrollees => {"$elemMatch" => {:rel_code => "self",
                                                                       :coverage_start => {"$gt" => active_start}}},
                                       :employer_id => {"$in" => employer_ids},
                                       :plan_id => {"$in" => plan_ids}}).no_timeout


    eligible_policies.each do |policy|
      if !policy.canceled?
        if !(policy.subscriber.coverage_start > active_end)
          employer = policy.employer
          next unless in_current_plan_year?(policy,employer,cutoff_date,active_start,active_end)
          subscriber = policy.subscriber
          next unless subscriber
          subscriber_id = policy.subscriber.m_id
          subscriber_person = policy.subscriber.person
          next unless subscriber_person
          auth_subscriber_id = subscriber_person.authority_member_id
          if subscriber_id == auth_subscriber_id
            yield policy
          end
        end
      end
    end
  end

  def find_active_start(market,cutoff_date)
    if market.downcase == 'ivl'
      active_start = cutoff_date.beginning_of_year - 1.day
    elsif market.downcase == 'shop'
      active_start = ((cutoff_date + 1.month) - 1.year) - 1.day
    end
    active_start
  end

  def find_active_end(cutoff_date)
    active_end = cutoff_date.end_of_month
    active_end
  end

  def get_employer_ids(active_start,active_end,market)
    if market.downcase == 'ivl'
      employer_ids = [nil]
    elsif market.downcase == 'shop'
      employer_ids = PlanYear.where(:start_date => {"$gt" => active_start, "$lt" => active_end}).map(&:employer_id)
    end
    employer_ids
  end

  def in_current_plan_year?(policy,employer,cutoff_date,active_start,active_end)
    if employer.blank?
      date_range = (active_start..active_end)
    else
      plan_year = current_plan_year(employer,cutoff_date,active_start,active_end)
      return false if plan_year.blank?
      py_start = plan_year.start_date
      py_end = plan_year.end_date
      date_range = (py_start..py_end)
    end
    policy_start_date = policy.subscriber.coverage_start
    if date_range.include?(policy_start_date)
      return true
    else
      return false
    end
  end

  def current_plan_year(employer,cutoff_date,active_start,active_end)
    current_range = (active_start..active_end)
    if current_range.include?(Time.now.to_date)
      today = Time.now.to_date
    else
      today = cutoff_date
    end
    plan_year = employer.plan_years.detect{|py| (py.start_date..py.end_date).include?(today)}
    plan_year
  end

  def generate_cv2s
    cutoff_date = Date.strptime(ENV['cutoff_date'], '%m-%d-%Y')
    system("rm -rf transformed_audits > /dev/null")
    Dir.mkdir("transformed_audits")

    transformer = TransformSimpleEdiFileSet.new('transformed_audits')

    puts "Started Generating Polices at #{Time.now}"
    pull_policies(ENV['market'],cutoff_date,ENV['carrier']) do |policy|
      begin
        affected_members = []
        select_enrollees(policy).each{|en| affected_members << BusinessProcesses::AffectedMember.new(:policy => policy, :member_id => en.m_id)}
        event_type = "urn:openhbx:terms:v1:enrollment#audit"
        tid = generate_transaction_id
        cv_render = render_cv(affected_members,policy,event_type,tid)
        transformer.transform(cv_render)
      rescue Exception=>e
        puts "Glue Policy ID: #{policy.id}, Glue Enrollment ID: #{policy.eg_id} failed - #{e.inspect}"
      end
    end
  end

  def select_enrollees(policy)
    enrollees = policy.enrollees.select{|en| !en.canceled?}
    return enrollees
  end

  def generate_transaction_id
    transaction_id ||= TransactionIdGenerator.generate_bgn02_compatible_transaction_id
    transaction_id
  end

  def render_cv(affected_members,policy,event_kind,transaction_id)
    render_result = ApplicationController.new.render_to_string(
         :layout => "enrollment_event",
         :partial => "enrollment_events/enrollment_event",
         :format => :xml,
         :locals => {
           :affected_members => affected_members,
           :policy => policy,
           :enrollees => select_enrollees(policy),
           :event_type => event_kind,
           :transaction_id => transaction_id
         })
  end
end

