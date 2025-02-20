require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,'0')[0..4]
end

def phone_number_validator(contents)
  contents.each do |row|
    phone = row[:homephone].split('').map {|char| Integer(char, exception: false) ? char : ''}.join('')
    if phone.length == 11 && phone.split('')[0] == '1'
      puts "#{row[:homephone][1..10]} is a good number."
    elsif phone.length == 10
      puts "#{row[:homephone]} is a good number."
    else
      puts "#{row[:homephone]} is a bad number."
    end
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

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def write_letters(contents)
  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter

  contents.each do |row|
    id = row[0]
    name = row[:first_name]

    zipcode = clean_zipcode(row[:zipcode])

    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id, form_letter)
  end
end

puts 'Event Manager Initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

# write_letters(contents)
phone_number_validator(contents)