# Repair mojibake in clues imported before the Nokogiri UTF-8 fix.
#
# Root cause: Nokogiri parsed j-archive.com (UTF-8) as Latin-1, so each
# multi-byte UTF-8 sequence was stored as individual Latin-1 codepoints.
# Questions have plain mojibake ("ElysÃ©e"). Answers additionally have
# HTML-entity-encoded mojibake ("ap&Atilde;&copy;ritif") because the
# scraper used .to_html before extracting the text.
#
# Fix: for questions, re-encode as ISO-8859-1 bytes then force UTF-8.
#      for answers, HTML-unescape first, then same re-encoding.
#
# Run with:
#   cd /srv/jservice && rails runner script/fix_encoding.rb
#
require 'cgi'

def fix_mojibake(s)
  s.encode('ISO-8859-1').force_encoding('UTF-8')
rescue Encoding::UndefinedConversionError, EncodingError
  s
end

fixed_q = 0
fixed_a = 0
errors  = 0

Clue.find_each do |clue|
  updates = {}

  q_fixed = fix_mojibake(clue.question)
  if q_fixed != clue.question && q_fixed.valid_encoding?
    updates[:question] = q_fixed
    fixed_q += 1
  end

  a_unescaped = CGI.unescapeHTML(clue.answer)
  a_fixed = fix_mojibake(a_unescaped)
  if a_fixed != clue.answer && a_fixed.valid_encoding?
    updates[:answer] = a_fixed
    fixed_a += 1
  end

  clue.update_columns(updates) unless updates.empty?
rescue => e
  errors += 1
  warn "Clue #{clue.id}: #{e}"
end

puts "Done. Fixed #{fixed_q} questions and #{fixed_a} answers (#{errors} errors)."
