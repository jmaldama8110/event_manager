require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcodes(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_home_phone(home_phone)
  clean_one = home_phone.to_s.delete(')').delete('(').delete('-').delete('+').delete('.').delete(' ')

  clean_one = clean_one.length < 10 || clean_one.length > 11 ? '0000000000' : clean_one
  clean_one[0] == '1' && clean_one.length == 11 ? clean_one[1..10] : clean_one
end

def peak_time_index(data)
  max_value = data[0]
  max_value_index = 0
  data.each_with_index do |_value, key|
    max_value_index = key + 1 if max_value < data[key + 1]
    max_value = data[key + 1] if max_value < data[key + 1]
    break if key == data.length - 2
  end
  max_value_index
end

def peak_timing(data)
  max_val_index = peak_time_index(data)
  hours = []
  data.each_with_index do |value, key|
    hours.push(key) if value == data[max_val_index]
  end
  hours
end

puts 'Event Manager Initialized...'

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

# saves the array of hours
hours = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
w_days = [0, 0, 0, 0, 0, 0, 0]

contents.each do |row|
  name = row[:first_name]
  id = row[0]

  zipcode = clean_zipcodes(row[:zipcode])
  home_phone = clean_home_phone(row[:homephone])

  regdate_time = Time.strptime(row[:regdate], '%m/%d/%y %k:%M')

  wday = regdate_time.wday
  hour = regdate_time.hour
  hours[hour] += 1
  w_days[wday] += 1
  puts "#{id}.- #{name}, #{zipcode}, #{home_phone}, #{regdate_time} (hora:#{hour})"

  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)

end

puts w_days.to_s
puts hours.to_s
puts "Concurrency happens at...#{peak_timing(hours)}"
puts "Concurrency on the weeks happens at.. #{peak_timing(w_days)}"
