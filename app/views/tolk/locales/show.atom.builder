atom_feed do |feed|
  feed.title "Missing Translations for #{@locale.language_name} locale"

  @phrases.each do |phrase|
    feed.entry(phrase, :url => tolk_locale_url(@locale)) do |entry|
      entry.title(phrase.pkey)
      entry.content(phrase.pkey)
      entry.author {|author| author.name("Tolk, Redis Tolk") }
    end
  end
end
