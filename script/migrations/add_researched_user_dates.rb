require 'csv'

$logger = Logger.new("#{Rails.root}/log/user_creation_updates_logger_#{Time.now.to_s.gsub(' ', '')}.log")

CSV.foreach("missing_dates.csv", headers: true) do |row|
  email, date, *_whatever = row.fields
  created_at = Time.strptime(date + "EST", "%Y-%m-%dT %H:%M:%S %Z")
  user = User.where({email: Regexp.compile(Regexp.escape(email), true)}).first
  if user
  if user.created_at.blank?
    puts([email, created_at].inspect)
    User.where({email: Regexp.compile(Regexp.escape(email), true)}).update({"$set" => {"created_at" => created_at}})
    $logger.info "Successfully updated #{user.email} with new created_at date of #{created_at}"
  else
    $logger.info "Did not update #{user.email} with remember_created_at date of #{created_at} because of existing created_at date of #{user.created_at}"
  end
  end
end
