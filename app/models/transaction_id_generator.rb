class TransactionIdGenerator
  def self.generate_bgn02_compatible_transaction_id
    ran = Random.new
    current_time = Time.now.utc
    # Time#usec (micro seconds) is NOT zero padded.
    # However, the example in the documentation only shows examples
    # with non zero leading numbers: https://ruby-doc.org/core-2.6.3/Time.html#method-i-usec
    # If you aren't careful, you might have a value for
    # usec that causes them to come out of order if you don't zero pad.
    # If the time (in seconds) value is:
    #  0.000789 => Time#usec is '789'
    #  0.123456 => Time#usec is '123'
    # If you naively compare these without padding, they will be
    # out of order even if they come after each other.
    # BUT, if you are operating on different seconds, you will get the
    # right order.
    # So two things need to happen to make this 'wrong':
    # - 2 transactions must publish during the same second
    # - the usec value must line up in a way that makes them ordered wrong
    #   because of missing padding
    reference_number_base = current_time.strftime("%Y%m%d%H%M%S") + sprintf("%06i", current_time.usec).to_s[0..2]
    reference_number_base + sprintf("%05i", ran.rand(65535))
  end
end