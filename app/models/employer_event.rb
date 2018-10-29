require 'zip'

class EmployerEvent
  include Mongoid::Document
  include Mongoid::Timestamps

  field :event_time, type: Time
  field :event_name, type: String
  field :resource_body, type: String
  field :employer_id, type: String

  XML_NS = "http://openhbx.org/api/terms/1.0"

  index({event_time: 1, event_name: 1, employer_id: 1})

  def self.newest_event?(new_employer_id, new_event_name, new_event_time)
    !self.where(:employer_id => new_employer_id, :event_name => new_event_name, :event_time => {"$gte" => new_event_time}).any?
  end

  def self.not_yet_seen_by_carrier?(new_employer_id)
    self.where(:event_name => EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME, :employer_id => new_employer_id).any?
  end

  def self.create_new_event_and_remove_old(new_employer_id, new_event_name, new_event_time, new_payload, match_criteria)
    new_event = self.create!({
      employer_id: new_employer_id,
      event_name: new_event_name,
      event_time: new_event_time,
      resource_body: new_payload
    })
    self.where(match_criteria.merge({:_id => {"$ne" => new_event._id}})).each do |old_record|
      yield old_record
      old_record.destroy
    end
  end

  def self.store_and_yield_deleted(new_employer_id, new_event_name, new_event_time, new_payload)
    employer_importer = ::EmployerEvents::EmployerImporter.new(new_payload)
    employer_importer.persist
    if not_yet_seen_by_carrier?(new_employer_id) || (new_event_name == EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME)
      latest_time = ([new_event_time] + self.where(:employer_id => new_employer_id).map(&:event_time)).max
      create_new_event_and_remove_old(

        new_employer_id,
        EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME,
        latest_time,
        new_payload,
        {:employer_id => new_employer_id}) do |old_record|
          yield old_record
      end
    else
      create_new_event_and_remove_old(
        new_employer_id,
        new_event_name,
        new_event_time,
        new_payload,
        {:employer_id => new_employer_id, :event_name => new_event_name}) do |old_record|
          yield old_record
      end
    end
  end

  def self.get_digest_for(carrier)
    events = self.order_by(event_time: 1)
    carrier_file = EmployerEvents::CarrierFile.new(carrier)
    events.each do |ev|
      event_renderer = EmployerEvents::Renderer.new(ev)
      carrier_file.render_event_using(event_renderer)
    end
    carrier_file.result
  end

  def self.clear_before(boundry_time)
    self.delete_all(event_time: {"$lt" => boundry_time})
  end

  def self.execute_pending_enrollment_requests(connection, boundry_time = Time.now)
    events = self.where(event_time: {"$lt" => boundry_time}).order_by(event_time: 1)
    trigger = EmployerEvents::EnrollmentEventTrigger.new
    events.each do |event|
      trigger.add(event)
    end
    trigger.publish(connection)
  end

  def self.with_digest_payloads(boundry_time = Time.now)
    events = self.where(event_time: {"$lt" => boundry_time}).order_by(event_time: 1)
    carrier_files = Carrier.all.map do |car|
      EmployerEvents::CarrierFile.new(car)
    end
    events.each do |ev|
      event_renderer = EmployerEvents::Renderer.new(ev)
      carrier_files.each do |car|
        car.render_event_using(event_renderer)
      end
    end
    carrier_files.each do |cf|
      unless cf.empty?
        f_name, data = cf.result
        yield data
      end
    end
  end

  def self.get_all_digests
    events = self.order_by(event_time: 1)
    carrier_files = Carrier.all.map do |car|
      EmployerEvents::CarrierFile.new(car)
    end
    events.each do |ev|
      event_renderer = EmployerEvents::Renderer.new(ev)
      carrier_files.each do |car|
        car.render_event_using(event_renderer)
      end
    end
    z_file = Tempfile.new("employer_events_digest")
    zip_path = z_file.path + ".zip"
    z_file.close
    z_file.unlink
    ::Zip::File.open(zip_path, ::Zip::File::CREATE) do |zip|
      carrier_files.each do |car|
        car.write_to_zip(zip)
      end
    end
    zip_path
  end

end
