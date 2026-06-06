puts "Seeding Alchemy CMS..."

# -- Site --
host = ENV.fetch('ALCHEMY_HOST', 'localhost')
site = Alchemy::Site.find_or_create_by!(host: host) do |s|
  s.name   = 'VeriFaith'
  s.public = true
end
puts "  Site: #{site.name} (#{site.host})"

# -- Language --
language = Alchemy::Language.find_or_create_by!(language_code: 'en', site: site) do |l|
  l.name           = 'English'
  l.frontpage_name = 'Home'
  l.page_layout    = 'home'
  l.default        = true
  l.public         = true
end
puts "  Language: #{language.name}"

# -- Root page (tree root — invisible node required by awesome_nested_set) --
root = Alchemy::Page.find_by(parent_id: nil)
unless root
  root = Alchemy::Page.new(
    name:          'Root',
    language_code: language.language_code,
    language:      language,
    restricted:    false,
    robot_index:   true,
    robot_follow:  true,
    sitemap:       false,
    layoutpage:    false
  )
  root.save!(validate: false)
  puts "  Created root page"
end

# -- Language root page (the actual homepage) --
lang_root = Alchemy::Page.find_by(language_root: true, language: language)
unless lang_root
  lang_root = Alchemy::Page.new(
    name:          'Home',
    urlname:       '',
    title:         'VeriFaith — Truth You Can Test',
    page_layout:   'home',
    language_code: language.language_code,
    language:      language,
    language_root: true,
    parent_id:     root.id,
    restricted:    false,
    robot_index:   true,
    robot_follow:  true,
    sitemap:       true,
    published_at:  Time.current
  )
  lang_root.save!(validate: false)
  puts "  Created language root (Home)"
end

# -- Child pages --
pages_config = [
  {
    name:          'Privacy Policy',
    urlname:       'privacy',
    page_layout:   'standard',
    title:         'Privacy Policy | VeriFaith',
    meta_desc:     'VeriFaith Privacy Policy — how we collect, use, and protect your personal information.',
    hero_headline: 'VeriFaith Privacy Policy',
    hero_subtitle: 'Effective Date: 02 Jan, 2025 · Last Updated: 15 May, 2025',
  },
  {
    name:          'Terms of Use',
    urlname:       'terms',
    page_layout:   'standard',
    title:         'Terms of Use | VeriFaith',
    meta_desc:     'VeriFaith Terms of Use — governing your access to and use of the VeriFaith platform.',
    hero_headline: 'VeriFaith Terms of Use',
    hero_subtitle: 'Effective Date: 02 Jan, 2025 · Last Updated: 15 May, 2025',
  },
  {
    name:          'FAQ',
    urlname:       'faq',
    page_layout:   'faq',
    title:         'Frequently Asked Questions | VeriFaith',
    meta_desc:     'Answers to the most common questions about VeriFaith.',
    hero_headline: 'Frequently Asked Questions',
    hero_subtitle: 'Everything you need to know about VeriFaith.',
  },
  {
    name:          'Mission',
    urlname:       'mission',
    page_layout:   'standard',
    title:         'Our Mission | VeriFaith',
    meta_desc:     'VeriFaith Mission Statement — rebuilding religion on verified truth.',
    hero_headline: 'VeriFaith Mission Statement',
    hero_subtitle: "Religion Was Built on Limited Information. We're Here to Rebuild it on Verified Truth.",
  },
  {
    name:          'Sources',
    urlname:       'sources',
    page_layout:   'standard',
    title:         'Sources & References | VeriFaith',
    meta_desc:     'The religious texts, translations, and scholarly sources used by VeriFaith.',
    hero_headline: 'Sources & References',
    hero_subtitle: "The texts and scholarly sources that power VeriFaith's verification engine.",
  },
  {
    name:          'Contact',
    urlname:       'contact',
    page_layout:   'contact',
    title:         'Contact Us | VeriFaith',
    meta_desc:     'Get in touch with the VeriFaith team.',
    hero_headline: "We're Available For You 24/7",
    hero_subtitle: 'No matter the time of day, our support team is always here to assist you.',
  },
]

pages_config.each do |cfg|
  existing = Alchemy::Page.find_by(urlname: cfg[:urlname], language: language)
  if existing
    puts "  Skipping '#{cfg[:name]}' — already exists"
    next
  end

  page = Alchemy::Page.new(
    name:             cfg[:name],
    urlname:          cfg[:urlname],
    title:            cfg[:title],
    meta_description: cfg[:meta_desc],
    page_layout:      cfg[:page_layout],
    language_code:    language.language_code,
    language:         language,
    language_root:    false,
    parent_id:        lang_root.id,
    restricted:       false,
    robot_index:      true,
    robot_follow:     true,
    sitemap:          true,
    published_at:     Time.current
  )

  unless page.save(validate: false)
    puts "  ERROR saving '#{cfg[:name]}': #{page.errors.full_messages.join(', ')}"
    next
  end

  # Add content via page version and elements
  draft = page.draft_version
  if draft
    hero_el = Alchemy::Element.create!(name: 'page_hero', page_version: draft)
    hero_el.ingredient_by_role(:headline)&.update!(value: cfg[:hero_headline])
    hero_el.ingredient_by_role(:subtitle)&.update!(value: cfg[:hero_subtitle])

    if cfg[:page_layout] == 'contact'
      contact_el = Alchemy::Element.create!(name: 'contact_section', page_version: draft)
      contact_el.ingredient_by_role(:headline)&.update!(value: 'Contact Us')
      contact_el.ingredient_by_role(:subtitle)&.update!(value: "Have a question in mind? Reach out — we'd love to hear from you.")
      contact_el.ingredient_by_role(:email)&.update!(value: 'legal@verifaith.org')
    elsif cfg[:page_layout] != 'faq'
      text_el = Alchemy::Element.create!(name: 'text_section', page_version: draft)
      text_el.ingredient_by_role(:headline)&.update!(value: 'Content')
      text_el.ingredient_by_role(:content)&.update!(value: '<p>Edit this content in the Alchemy CMS admin at <strong>/cms/admin</strong>.</p>')
    end

    # Publish: set public_on on this version (makes it the public version)
    # then create a fresh draft version so the admin editor always has one to work with
    draft.update_column(:public_on, Time.current)
    Alchemy::PageVersion.create!(page: page, public_on: nil)
  end

  puts "  Created: #{cfg[:name]} (#{cfg[:page_layout]}) — /#{cfg[:urlname]}"
end

puts "✓ Alchemy CMS seeded"
