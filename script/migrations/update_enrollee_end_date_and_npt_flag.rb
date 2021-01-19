#steps to run this script 
#1. Create a csv with 4 columns Subscriber HBX ID, Glue Enrollment Group ID, Correct End Date and NPT Status
#2. save the csv file namw with enrollee_end_date_npt_flag.csv
#3. Script to run it on Production env is bundle exec rails r script/migrations/update_enrollee_end_date_and_npt_flag.rb -e production

FILE_PATH = "#{Rails.root}/enrollee_end_date_npt_flag.csv" 

def update_enrollee_end_date_and_npt_flag(subscriber_hbx_id, eg_id, coverage_end, npt_flag)
  pol = Policy.where(hbx_enrollment_ids: eg_id).first
  if pol.present?
    enrollee = pol.enrollees.where(m_id: subscriber_hbx_id).first
    if enrollee.present?
      enrollee.update_attributes!(coverage_end: coverage_end)
      pol.update_attributes!(term_for_np: npt_flag)
      puts "Successfully updated enrollee coverage end to #{enrollee.coverage_end} and npt_flag:#{pol.term_for_np} for the policy with eg_id: #{eg_id} "
      puts "*"*20
    else
      puts "Did not find enrollee with hbx_id: #{subscriber_hbx_id} for the policy with eg_id: #{eg_id}"
    end
  else
    puts "Did not find policy with eg_id: #{eg_id}"
  end
end

CSV.read(FILE_PATH).each do |row|
  # Skips the header Row
  next if CSV.read(FILE_PATH)[0] == row
  # Removes nil values (blank cells) from row array
  row = row.compact
  # Skips entirely blank rows
  next if row.length == 0
  subscriber_hbx_id = row[0]
  eg_id = row[1]
  coverage_end = row[2]
  npt_flag = row[3]
  update_enrollee_end_date_and_npt_flag(subscriber_hbx_id, eg_id, coverage_end, npt_flag)
end