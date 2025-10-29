# Seed data for Directions
puts "Creating Directions..."

directions_data = [
  {
    code: "LTR",
    name: "Left-to-Right",
    description: "Text flows from left to right (e.g., English, Greek, Latin)"
  },
  {
    code: "RTL",
    name: "Right-to-Left", 
    description: "Text flows from right to left (e.g., Arabic, Hebrew, Syriac)"
  }
]

directions_data.each do |data|
  direction = Direction.find_or_create_by(code: data[:code]) do |d|
    d.name = data[:name]
    d.description = data[:description]
  end
  
  if direction.persisted?
    puts "✓ Created Direction: #{direction.name} (#{direction.code})"
  else
    puts "✗ Failed to create Direction: #{data[:name]} - #{direction.errors.full_messages.join(', ')}"
  end
end

puts "Directions seeding completed!"
puts "Total Directions: #{Direction.count}"
