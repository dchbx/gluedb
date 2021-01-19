require 'csv'

CSV.foreach("missing_dates.csv", headers: true) do |row|
  email, date, *_whatever = row.fields
  created_at = Time.strptime(date + "EST", "%Y-%m-%dT %H:%M:%S %Z")
  user = User.where({email: Regexp.compile(Regexp.escape(email), true)}).first
  if user
    if user.created_at.blank?
      puts([email, created_at].inspect)
      User.where({email: Regexp.compile(Regexp.escape(email), true)}).update({"$set" => {"created_at" => created_at}})
    end
  end
end
