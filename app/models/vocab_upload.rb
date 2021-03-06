class VocabUpload
  attr_accessor :kind
  attr_accessor :submitted_by
  attr_accessor :vocab
  attr_accessor :bypass_validation
  attr_accessor :csl_number
  attr_accessor :redmine_ticket

  ALLOWED_ATTRIBUTES = [:kind, :submitted_by, :vocab, :csl_number,  :redmine_ticket]

  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Naming

  validates_inclusion_of :kind, :in => ["maintenance", "initial_enrollment"], :allow_blank => false, :allow_nil => false
  validates_presence_of :submitted_by
  validates_presence_of :vocab

  def initialize(options={})
    options.each_pair do |k,v|
      if ALLOWED_ATTRIBUTES.include?(k.to_sym)
        self.send("#{k}=", v)
      end
    end
  end

  def save(listener)
    return(false) unless self.valid?
    file_data = vocab.read
    file_name = vocab.original_filename

    unless bypass_validation
      doc = Nokogiri::XML(file_data)

      change_request = Parsers::Xml::Enrollment::ChangeRequestFactory.create_from_xml(doc)
      plan = Plan.find_by_hios_id_and_year(change_request.hios_plan_id, change_request.plan_year)
      validations = [
        Validators::PremiumValidator.new(change_request, plan, listener),
        Validators::PremiumTotalValidatorFactory.create_for(change_request, listener),
        Validators::PremiumResponsibleValidator.new(change_request, listener),
        Validators::AptcValidator.new(change_request, plan, listener)
      ]

      if validations.any? { |v| v.validate == false }
        return false
      end
    end

    log_upload(file_name, file_data)
    submit_cv(kind, file_name, file_data)
    true
  end

  def submit_cv(cv_kind, name, data)
    return if Rails.env.test?
    tag = (cv_kind.to_s.downcase == "maintenance")
    pubber = ::Services::CvPublisher.new(submitted_by)
    pubber.publish(tag, name, data)
  end

  def persisted?
    false
  end

  def log_upload(file_name, file_data)
    broadcast_info = {
      :routing_key => "info.events.legacy_enrollment_vocabulary.uploaded",
      :app_id => "gluedb",
      :headers => {
        "file_name" => file_name,
        "kind" =>  kind,
        "submitted_by"  => submitted_by,
        "bypass_validation" => bypass_validation.to_s
      }
    }
    if !csl_number.blank?
      broadcast_info[:headers]["csl_number"] = csl_number
    end
    if !redmine_ticket.blank?
      broadcast_info[:headers]["redmine_ticket"] = redmine_ticket
    end
    Amqp::EventBroadcaster.with_broadcaster do |eb|
      eb.broadcast(broadcast_info, file_data)
    end
  end
end
