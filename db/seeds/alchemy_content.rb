puts "Populating Alchemy elements with real page content..."

lang = Alchemy::Language.default

def populate_page(page, hero:, sections: [], faq_items: [], contact: nil)
  [page.draft_version, page.public_version].compact.each do |version|
    Alchemy::Element.where(page_version: version).destroy_all

    hero_el = Alchemy::Element.create!(name: 'page_hero', page_version: version)
    hero_el.ingredient_by_role(:headline)&.update!(value: hero[:headline].to_s)
    hero_el.ingredient_by_role(:subtitle)&.update!(value: hero[:subtitle].to_s)
    hero_el.ingredient_by_role(:body_text)&.update!(value: hero[:body_text].to_s)

    sections.each do |s|
      el = Alchemy::Element.create!(name: 'text_section', page_version: version)
      el.ingredient_by_role(:headline)&.update!(value: s[:headline].to_s)
      el.ingredient_by_role(:content)&.update!(value: s[:content].to_s)
    end

    faq_items.each do |f|
      el = Alchemy::Element.create!(name: 'faq_item', page_version: version)
      el.ingredient_by_role(:question)&.update!(value: f[:question].to_s)
      el.ingredient_by_role(:answer)&.update!(value: f[:answer].to_s)
    end

    if contact
      el = Alchemy::Element.create!(name: 'contact_section', page_version: version)
      el.ingredient_by_role(:headline)&.update!(value: contact[:headline].to_s)
      el.ingredient_by_role(:subtitle)&.update!(value: contact[:subtitle].to_s)
      el.ingredient_by_role(:email)&.update!(value: contact[:email].to_s)
      el.ingredient_by_role(:phone)&.update!(value: contact[:phone].to_s)
      el.ingredient_by_role(:address)&.update!(value: contact[:address].to_s)
    end
  end
end

# ─── PRIVACY POLICY ────────────────────────────────────────────────────────────
page = Alchemy::Page.where(language: lang).find_by(urlname: 'privacy')
if page
  populate_page(page,
    hero: {
      headline:  'VeriFaith Privacy Policy',
      subtitle:  'Effective Date: 02 Jan, 2025 · Last Updated: 15 May, 2025',
      body_text: '<p>VeriFaith, Inc. ("VeriFaith", "we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, share, store, and protect your personal information when you use our websites, mobile applications, platform services, and any other features, technologies, or functionalities offered by VeriFaith (collectively, the "Services").</p><p>By using VeriFaith, you acknowledge that you have read and understand this Privacy Policy.</p>'
    },
    sections: [
      {
        headline: '1. Information We Collect',
        content: '<h3>1.1 Information You Provide to Us</h3><ul><li><strong>Account Information:</strong> When you create an account, we collect your name, email address, password (hashed), and optional profile data (e.g., display name, biography).</li><li><strong>Payment Information:</strong> When you subscribe or make purchases, your payment details (e.g., credit/debit card, billing address) are collected by our third-party processor (e.g., Stripe). We do not store full payment information on our servers.</li><li><strong>User-Generated Content:</strong> When you submit claims, evidence, theories, challenges, or comments, we collect this content and any associated metadata.</li><li><strong>Support and Communications:</strong> If you contact us directly, we may store your communications, including name, email address, and message content.</li></ul><h3>1.2 Information We Automatically Collect</h3><ul><li><strong>Device and Usage Information:</strong> We collect basic information such as your IP address, browser type, device type, operating system, and timestamps of activity.</li><li><strong>Cookies and Tracking Technologies:</strong> We use strictly necessary cookies for session management, security, and functionality. No advertising cookies or third-party behavioral trackers are used.</li><li><strong>Log Data:</strong> We may log usage patterns, clicks, and navigation for internal analytics purposes.</li></ul><h3>1.3 Information We Do Not Collect</h3><p>VeriFaith does not collect or track:</p><ul><li><strong>GPS or precise geolocation</strong></li><li><strong>Biometric, health, or financial account data</strong></li><li><strong>Audio, camera, or microphone input (unless explicitly submitted)</strong></li><li><strong>Contacts, text messages, or background app usage</strong></li></ul>'
      },
      {
        headline: '2. How We Use Your Information',
        content: '<p>We use your data to:</p><ul><li><strong>Provide, operate, and improve the Services</strong></li><li><strong>Authenticate users and secure access</strong></li><li><strong>Process transactions and manage subscriptions</strong></li><li><strong>Log and display claim validation results</strong></li><li><strong>Respond to inquiries and customer service requests</strong></li><li><strong>Analyze usage trends (anonymously) to enhance features and user experience</strong></li><li><strong>Prevent fraud, abuse, and violations of our Terms</strong></li></ul>'
      },
      {
        headline: '3. How We Protect Your Data',
        content: '<ul><li><strong>Encryption:</strong> All data is transmitted over HTTPS using industry-standard TLS encryption.</li><li><strong>Storage:</strong> User data is stored on secure, access-controlled servers.</li><li><strong>Access Control:</strong> Only authorized personnel with a business need may access personal data.</li><li><strong>Vendor Compliance:</strong> Third-party service providers (e.g., cloud storage, payment processors) are required to meet GDPR and CCPA compliance standards.</li></ul>'
      },
      {
        headline: '4. How We Share Your Information',
        content: '<p>We do not sell, rent, or trade your personal information. We may share information with:</p><ul><li><strong>Service Providers:</strong> Vendors performing services on our behalf (e.g., payment processing, email delivery, infrastructure hosting).</li><li><strong>Legal and Compliance:</strong> To comply with applicable law, regulation, legal process, or enforceable government request.</li><li><strong>Business Transfers:</strong> If VeriFaith is involved in a merger, acquisition, or sale of assets, your data may be transferred subject to this Policy.</li></ul><p>All third parties are contractually bound to use data only as necessary to perform their services and maintain confidentiality.</p>'
      },
      {
        headline: '5. Analytics & Aggregated Data Use',
        content: '<p>VeriFaith may use aggregated, de-identified data for:</p><ul><li><strong>Analyzing user behavior and platform usage trends</strong></li><li><strong>Publishing insights</strong> (e.g., most validated claims, theological theory trends)</li><li><strong>Offering group-level metrics to sponsors, scholars, and institutional partners</strong></li></ul><p>This data does not identify you individually, cannot be traced back to your personal account, and is never combined with profile or billing information. We will never sell your personal data.</p>'
      },
      {
        headline: '6. Your Data Rights',
        content: '<h3>Under GDPR (EU Users)</h3><ul><li>Right to access your data</li><li>Right to rectify inaccurate data</li><li>Right to erasure ("right to be forgotten")</li><li>Right to restrict or object to processing</li><li>Right to data portability</li><li>Right to withdraw consent</li></ul><h3>Under CCPA (California Residents)</h3><ul><li>Right to know what personal information we collect</li><li>Right to delete your personal information</li><li>Right to opt out of "sale" of personal data (we do not sell personal data)</li><li>Right to non-discrimination for exercising your privacy rights</li></ul><p>To exercise these rights, email us at <a href="mailto:privacy@verifaith.org">privacy@verifaith.org</a>. We may require verification of your identity.</p>'
      },
      {
        headline: '7. Data Retention',
        content: '<ul><li>Personal account data is retained as long as you maintain an account.</li><li>Upon deletion, personal identifiers are removed from the system within 30 days.</li><li>Aggregated, anonymized data may be retained for research, audit, and trend analysis.</li><li>Financial records may be retained as required by law for tax or compliance purposes.</li></ul>'
      },
      {
        headline: '8. Cookies & Similar Technologies',
        content: '<p>We use:</p><ul><li><strong>Essential Cookies</strong> for login, session management, and security.</li><li><strong>Performance Cookies</strong> to analyze platform behavior (e.g., page load speed).</li></ul><p>We do not use behavioral advertising cookies or social media plugins with tracking capabilities. You can manage your cookie preferences in your browser settings.</p>'
      },
      {
        headline: "9. Children's Privacy",
        content: '<p>VeriFaith is not intended for use by individuals under the age of 16. We do not knowingly collect personal information from children without verifiable parental consent. If we become aware that a child under 16 has provided us with personal information, we will take steps to delete such information promptly.</p>'
      },
      {
        headline: '10. Changes To This Policy',
        content: '<p>We may update this Privacy Policy from time to time. We will notify you by posting the updated version to our site or emailing you if changes are material. Your continued use of VeriFaith after such changes constitutes your acceptance.</p>'
      },
      {
        headline: '11. Contact Us',
        content: '<p>If you have questions about this Privacy Policy or your personal data, please contact the VeriFaith Privacy Team:</p><ul><li><strong>Email:</strong> <a href="mailto:privacy@verifaith.org">privacy@verifaith.org</a></li><li><strong>Mail:</strong> Street 123 Florida, USA</li></ul>'
      }
    ]
  )
  puts "  OK: Privacy Policy (11 sections)"
end

# ─── TERMS OF USE ──────────────────────────────────────────────────────────────
page = Alchemy::Page.where(language: lang).find_by(urlname: 'terms')
if page
  populate_page(page,
    hero: {
      headline:  'VeriFaith Terms of Use',
      subtitle:  'Effective Date: 02 Jan, 2025 · Last Updated: 15 May, 2025',
      body_text: '<p>These Terms of Use ("Terms") govern your access to and use of the VeriFaith platform, services, websites, applications, and tools (collectively, the "Services") operated by VeriFaith, Inc. ("VeriFaith," "we," "our," or "us").</p><p>By creating an account, submitting content, making a payment, or using the platform in any way, you agree to be bound by these Terms and all related policies (Privacy Policy, AI &amp; Data Use Policy, etc.).</p>'
    },
    sections: [
      {
        headline: '1. Eligibility & Accounts',
        content: '<ul><li>You must be at least 16 years old to use VeriFaith.</li><li>You are responsible for maintaining the security of your account credentials.</li><li>You agree not to impersonate another person or misrepresent your identity.</li></ul>'
      },
      {
        headline: '2. Purpose of VeriFaith',
        content: '<p>VeriFaith is a fact-based platform for submitting, validating, and challenging religious and historical claims using a method called Literal Source Verification (LSV). This platform is designed for <strong>neutral, source-bound engagement</strong> — not theological teaching, spiritual counseling, or opinion forums.</p>'
      },
      {
        headline: '3. Paid Subscriptions & Billing',
        content: '<ul><li>Some features of VeriFaith (e.g., submitting claims, posting theories, accessing validation tools) require a paid subscription.</li><li>By subscribing, you authorize VeriFaith (via Stripe or other provider) to charge your payment method on a recurring basis unless canceled.</li><li>You are responsible for keeping your payment information current.</li><li>All prices are displayed in USD unless otherwise noted.</li></ul>'
      },
      {
        headline: '4. Refund & Return Policy',
        content: '<p><strong>VeriFaith does not offer refunds or returns.</strong></p><p>Due to the nature of digital access and AI-powered services, all payments are final. You may cancel future renewals at any time via your account dashboard, but <strong>no partial or retroactive refunds will be issued</strong>, including for unused time or credits.</p><p>If you believe you were charged in error, you must contact us at <a href="mailto:billing@verifaith.org">billing@verifaith.org</a> within 5 business days of the transaction. Chargeback abuse will result in account termination.</p>'
      },
      {
        headline: '5. User Content & Submissions',
        content: '<p>By submitting any content (claims, challenges, theories, comments, or other contributions), you agree that:</p><ul><li>You will only submit content that is truthful, factual, and capable of verification through scripture or history.</li><li>You will not submit theological opinions or interpretations, speculative or deceptive content, or hate speech, spam, or discriminatory material.</li><li>You retain ownership of your submitted content, but grant VeriFaith a <strong>perpetual, non-exclusive, royalty-free license</strong> to display, reproduce, store, and use that content within the platform.</li></ul><p>We reserve the right to <strong>remove or flag content</strong> that violates these Terms or fails to meet LSV standards.</p>'
      },
      {
        headline: '6. Changes to Services',
        content: '<p>VeriFaith reserves the right to add, modify, or remove features; change pricing or subscription models; introduce new AI validators or supported canons; and update these Terms or related policies. Material changes will be communicated to users via email or in-platform notice. Continued use of the Services after such changes constitutes acceptance.</p>'
      },
      {
        headline: '7. Prohibited Uses',
        content: '<p>You agree not to use the platform to:</p><ul><li>Attempt to reverse engineer AI validators or source selection logic</li><li>Mine user data or scrape religious content</li><li>Share your account access with others without permission</li><li>Circumvent subscription paywalls or impersonate other users</li></ul><p>Violation of these terms may result in immediate account termination.</p>'
      },
      {
        headline: '8. Warranty Disclaimer',
        content: '<p>VeriFaith is provided <strong>"as is"</strong> and <strong>"as available."</strong> We make no guarantees that all claims or theories are accurate, that validation results will be uniform across all models, or that religious or spiritual interpretations will align with any faith tradition. You use the platform at your own discretion. We do not guarantee spiritual, theological, or personal outcomes.</p>'
      },
      {
        headline: '9. Limitation of Liability',
        content: '<p>To the fullest extent permitted by law, VeriFaith shall not be liable for any indirect, incidental, special, or consequential damages; losses resulting from the use of or reliance on any claim, theory, or content; or disputes between users or between users and their religious institutions. Maximum liability for any claim related to the platform shall not exceed the <strong>amount paid by you in the preceding 12 months</strong>, if any.</p>'
      },
      {
        headline: '10. Disputes & Contact',
        content: '<p>If you experience a billing or content issue:</p><ul><li>Email <strong>support@verifaith.org</strong> or <strong>billing@verifaith.org</strong></li><li>We aim to resolve issues within <strong>5–7 business days</strong></li></ul><p>If necessary, disputes will be resolved under the laws of the applicable jurisdiction.</p>'
      },
      {
        headline: '11. Governing Law',
        content: '<p>These Terms are governed by and construed in accordance with applicable U.S. federal laws and the laws of the State of Florida, without regard to conflict-of-law principles.</p>'
      },
      {
        headline: '12. Entire Agreement',
        content: '<p>These Terms, along with our Privacy Policy and AI &amp; Data Use Policy, constitute the entire agreement between you and VeriFaith. They supersede any prior agreements or understandings, written or oral.</p><p>Questions about these Terms? Contact us at <a href="mailto:legal@verifaith.org">legal@verifaith.org</a> or write to us at Street 123 Florida, USA.</p>'
      }
    ]
  )
  puts "  OK: Terms of Use (12 sections)"
end

# ─── FAQ ───────────────────────────────────────────────────────────────────────
page = Alchemy::Page.where(language: lang).find_by(urlname: 'faq')
if page
  populate_page(page,
    hero: {
      headline: 'Frequently Asked Questions',
      subtitle: 'Everything you need to know about VeriFaith.'
    },
    faq_items: [
      {
        question: 'Why does VeriFaith charge for submissions and memberships?',
        answer: '<p>VeriFaith charges for several reasons:</p><ul><li><strong>API usage:</strong> Each claim or challenge runs through multiple AI models, original-language tools, and validator logic — all of which incur real-time costs.</li><li><strong>Preventing abuse:</strong> Free accounts are often exploited by bots or trolls. Paid access ensures serious participation and protects the integrity of the validation process.</li><li><strong>Support for transparency and growth:</strong> Subscriptions help fund validator development, peer review tooling, global access initiatives, and free educational content from our nonprofit partner <a href="https://literalverification.org" target="_blank">LiteralVerification.org</a>.</li></ul><p>We\'re not charging for truth — we\'re charging for the tools required to protect and verify it responsibly.</p>'
      },
      {
        question: 'What qualifies as a Fact on VeriFaith?',
        answer: '<p>A Fact is a claim that:</p><ol><li>Is clear, absolute, and testable</li><li>Is supported by literal source evidence (e.g., scripture, history)</li><li>Is validated by AI using LSV logic</li><li>Is confirmed by at least 2 peer validators</li><li>Has no unresolved challenges</li></ol><p>Facts are always open to re-validation if new evidence or a legitimate challenge is submitted.</p>'
      },
      {
        question: 'What is Literal Source Verification (LSV)?',
        answer: '<p>LSV is the framework we use to test claims. It requires:</p><ul><li><strong>Validation from original language sources</strong></li><li><strong>No interpretation, tradition, or theology</strong></li><li><strong>AI analysis + peer review agreement</strong></li></ul><p>It\'s maintained by the nonprofit <a href="https://literalverification.org" target="_blank">LiteralVerification.org</a> and used by VeriFaith to ensure every claim is evidence-based, not belief-driven.</p>'
      },
      {
        question: 'Can anyone be a peer validator?',
        answer: '<p>Yes — but only after passing a basic validator onboarding process that tests:</p><ul><li>Familiarity with LSV rules</li><li>Commitment to neutral, source-based reasoning</li><li>Willingness to engage constructively</li></ul><p>Peer validators do not vote based on belief — they confirm whether the claim meets LSV standards. Validators from all religions (or none) are welcome if they follow the logic.</p>'
      },
      {
        question: 'Can Facts or Theories change?',
        answer: '<p>Yes. If a new source is submitted, a valid challenge is raised, or a peer validator flags a contradiction, then the claim or theory is revalidated. If it fails, it\'s downgraded or removed. Truth on VeriFaith is not fixed — it\'s living, and constantly pressure-tested.</p>'
      },
      {
        question: 'Can I submit claims from any religion?',
        answer: '<p>Yes. VeriFaith is cross-religious and supports claims from:</p><ul><li>Judaism</li><li>Christianity</li><li>Islam</li><li>Hinduism</li><li>Buddhism</li><li>Sikhism</li><li>Zoroastrianism</li><li>And more...</li></ul><p>You can submit from any recognized canon, so long as the claim is verifiable under LSV rules.</p>'
      },
      {
        question: 'Why are some Theories marked as "Under Review"?',
        answer: '<p>Theories are built from multiple validated Facts. If a Fact is challenged, a Theory includes ambiguous reasoning, or it hasn\'t yet passed minimum review thresholds, it will remain marked as "Under Review" until all components are validated. Theories must be built on facts, not stacked assumptions.</p>'
      },
      {
        question: 'Will VeriFaith ever push one religion or interpretation?',
        answer: '<p>VeriFaith will never push any religion or interpretation. Premium users and Leaders can create and publish theories. Users can then filter based on the sources being used, percentage of facts being used, and trending theories. But it must always be user-defined filtering to find what they want — never software promotion.</p>'
      },
      {
        question: 'Can I share a Theory publicly?',
        answer: '<p>Yes — Premium and Leader accounts can publish theories publicly on VeriFaith. Published theories are visible to all users and subject to community review and challenges. Theories must meet minimum Fact thresholds before they can be shared publicly.</p>'
      }
    ]
  )
  puts "  OK: FAQ (9 items)"
end

# ─── MISSION ───────────────────────────────────────────────────────────────────
page = Alchemy::Page.where(language: lang).find_by(urlname: 'mission')
if page
  populate_page(page,
    hero: {
      headline:  'VeriFaith Mission Statement',
      subtitle:  "Religion Was Built on Limited Information. We're Here to Rebuild it on Verified Truth.",
      body_text: '<p>For centuries, theology was shaped by people who did the best they could — with very little. They worked from incomplete texts, translations of translations, and traditions passed down as unquestioned truth. They had almost no access to other religious canons, original manuscripts, or historical context outside their own region or sect. Yet these assumptions became doctrines. Those doctrines became institutions. And we inherited it all.</p>'
    },
    sections: [
      {
        headline: 'Today, That Era Is Over',
        content: '<p>We now live in a world where:</p><ul><li><strong>Every major sacred text</strong> is digitized and searchable</li><li><strong>Original languages</strong> like Hebrew, Greek, Arabic, Sanskrit, Pali, and Ge\'ez are accessible and analyzable</li><li><strong>AI can process claims</strong> using logic, linguistic accuracy, and strict source boundaries</li><li><strong>Cross-religion comparison</strong> is instant and transparent</li></ul><p>We have better tools than any generation before us. It\'s time to stop defending inherited belief and start testing it.</p>'
      },
      {
        headline: 'Our Mission Is Clear',
        content: '<p><strong>Let the Facts Build the Theology — Not the Other Way Around</strong></p><p>VeriFaith doesn\'t interpret. It validates. Using our Literal Source Verification (LSV) framework, every claim must:</p><ul><li>Be worded with absolute clarity</li><li>Be testable against a specific source</li><li>Pass AI validation using original language analysis</li><li>Undergo peer and multi-model review</li></ul><p>Only claims that survive this process become Facts. Only Facts can form the building blocks of Theories.</p>'
      },
      {
        headline: 'A Living System Where Truth Holds Power and Pressure',
        content: '<p>Facts on VeriFaith aren\'t frozen. They can be challenged at any time. When a challenge is submitted, our system:</p><ul><li><strong>Revalidates the original claim</strong></li><li>Filters all evidence through source-specific AI logic</li><li>Reassesses the outcome based on updated models or stronger input</li></ul><p>If a better source disproves a Fact, it fails. If a Theory loses its foundation, it collapses. Because truth isn\'t what survives tradition. <strong>Truth is what survives pressure.</strong></p>'
      },
      {
        headline: 'Rebuilding Faith from the Bottom Up',
        content: '<p>You don\'t need to inherit someone else\'s belief. You don\'t need to trust a chain of interpretations passed down through centuries of filtered understanding. You can test it yourself. And so can everyone else.</p><p><strong>Facts over Fame.<br>Evidence over Emotion.<br>Truth over Tradition.</strong></p>'
      },
      {
        headline: 'Welcome to VeriFaith',
        content: '<p>Where Faith Isn\'t Inherited. It\'s Verified.</p>'
      }
    ]
  )
  puts "  OK: Mission (5 sections)"
end

# ─── SOURCES ───────────────────────────────────────────────────────────────────
page = Alchemy::Page.where(language: lang).find_by(urlname: 'sources')
if page
  populate_page(page,
    hero: {
      headline: 'Sources & References',
      subtitle: "The texts and scholarly sources that power VeriFaith's verification engine."
    },
    sections: [
      {
        headline: 'Arabic Qurʾān Text',
        content: '<p>The Arabic Qurʾān text used in this application is sourced from the Tanzil Project, specifically the Ḥafṣ ʿan ʿĀṣim recitation in Uthmānī script.</p><h3>Attribution Details</h3><ul><li><strong>Source:</strong> Tanzil Uthmani</li><li><strong>Publisher:</strong> Tanzil Project</li><li><strong>License:</strong> CC BY 3.0</li><li><strong>Website:</strong> <a href="https://tanzil.net/" target="_blank">https://tanzil.net/</a></li><li><strong>Recitation:</strong> Ḥafṣ ʿan ʿĀṣim</li><li><strong>Script:</strong> Uthmānī (globally standard orthography)</li></ul><h3>Data Integrity</h3><p>All Arabic text is stored with SHA-256 checksums to ensure data integrity. The original source files are preserved without modification.</p>'
      },
      {
        headline: 'Usage Rights & License Compliance',
        content: '<p>This application uses the Arabic Qurʾān text under the Creative Commons Attribution 3.0 license. The text is used without modification and proper attribution is provided.</p><ul><li>✅ Original text preserved without modification</li><li>✅ Proper attribution provided</li><li>✅ Source checksums maintained for verification</li><li>✅ License information clearly displayed</li></ul><p>For questions about data sources or to report issues, please <a href="/contact">contact us</a>.</p>'
      },
      {
        headline: 'Additional Sources',
        content: '<p>VeriFaith draws on a growing library of religious texts, original-language manuscripts, and scholarly references. Sources are continuously reviewed and expanded to support broader cross-religious verification. Updates to the source library are announced in the platform changelog.</p>'
      }
    ]
  )
  puts "  OK: Sources (3 sections)"
end

# ─── CONTACT ───────────────────────────────────────────────────────────────────
page = Alchemy::Page.where(language: lang).find_by(urlname: 'contact')
if page
  populate_page(page,
    hero: {
      headline:  "We're Available For You 24/7",
      subtitle:  'No matter the time of day, our support team is always here to assist you. Whether you have questions, need help with an issue, or just want to reach out, we\'re available around the clock to provide fast, reliable support — anytime you need it.'
    },
    contact: {
      headline: 'Contact Us',
      subtitle: "Have a question in mind? Reach out — we'd love to hear from you.",
      email:    'legal@verifaith.org',
      phone:    '+1-23456789',
      address:  'Street 123 Florida, United States'
    }
  )
  puts "  OK: Contact"
end

puts "✓ All page content populated in Alchemy"
