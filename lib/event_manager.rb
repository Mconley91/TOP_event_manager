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
  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    phone = phone_number_validator(row[:homephone])
    legislators = legislators_by_zipcode(zipcode)
    form_letter = erb_template.result(binding) #turns erb file into html, with the variable values as they exist in scope at this time
    save_thank_you_letter(id, form_letter)
  end
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