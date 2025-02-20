require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,'0')[0..4]
end

def phone_number_validator(phone)
    clean_phone_number = phone.split('').map {|char| Integer(char, exception: false) ? char : ''}.join('')
    if clean_phone_number.length == 11 && clean_phone_number.split('')[0] == '1'
      "#{phone[1..10]}"
    elsif clean_phone_number.length == 10
      "#{phone}"
    else
      "#{phone} (Invalid number. Please update your contact information)"
    end
end

def get_registration_time(regdate)
  am_or_pm = 'AM'
  hours_24 = regdate.split(" ")[1].split(':')[0].to_i
  if hours_24 > 12 
    hours_12 = hours_24 - 12 
    am_or_pm = 'PM'
  else
    hours_12 = hours_24
  end
  minutes = regdate.split(" ")[1].split(':')[1]
  "#{hours_12}:#{minutes} #{am_or_pm}"
end

def get_most_common_regtimes(regtimes)
  hours_to_eval = []
  regtimes.each do |time|
    time_split = time.split(/\W+/)
    hour = time_split[2] == 'PM' ? time_split[0].to_i + 12 : time_split[0]
    hours_to_eval << hour.to_i
  end
  top_3_hours_array = hours_to_eval.tally.to_a.sort {|a,b| a[1] <=> b[1]}.reverse[0..2].map {|hour| 
  if hour[0].to_i > 12
    "#{hour[0].to_i - 12} PM"
  else
    "#{hour[0].to_i} AM"
  end
  }
  top_3_hours_array
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secretkey.txt').strip
  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def write_letters(contents)
  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter
  regtimes = []
  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    phone = phone_number_validator(row[:homephone])
    regtime = get_registration_time(row[:regdate])
    regtimes << regtime
    legislators = legislators_by_zipcode(zipcode)
    form_letter = erb_template.result(binding) #turns erb file into html, with the variable values as they exist in scope at this time
    save_thank_you_letter(id, form_letter)
    # puts "NAME: #{name}", "ZIP: #{zipcode}", "PHONE: #{phone}", "REG_TIME: #{regtime}", " "
  end
  most_common_regtimes = get_most_common_regtimes(regtimes)
  puts most_common_regtimes
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)
puts 'event manager initialized...'

write_letters(contents)

puts '...done!'