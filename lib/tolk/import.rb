module Tolk
  module Import
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods

      def import_secondary_locales
        puts "[INFO] Starting to import secondary locales..."
        locales = Dir.entries(self.locales_config_path)
        locales = locales.reject {|l| ['.', '..'].include?(l) || !l.ends_with?('.yml') }.map {|x| x.split('.').first } - [Tolk::Locale.primary_locale.name]

        puts "[INFO] Secondary locales: #{locales.inspect}"
        for locale in locales
          puts "Tolk::Import >> importing locale: #{locale.inspect}"
          import_locale(locale)
        end
      end

      def import_locale(locale_name)
        ##locale = Tolk::Locale.find_or_create_by_name(locale_name)
        locale = (Tolk::Locale.find :name => locale_name).first # Ohm, remember that .find return all matching or []
        locale = Tolk::Locale.create :name => locale_name if locale.blank?
        data = locale.read_locale_file

        phrases = Tolk::Phrase.all
        saved,unsaved = 0,0

        puts "Locale: #{locale_name.inspect}  Phrases: #{phrases.all}   Data: #{data.size}"
        data.each do |key, value|
          phrase = phrases.detect {|p| p.pkey == key}

          if phrase
            ##translation = locale.translations.new(:text => value, :phrase => phrase)
            translation = Tolk::Translation.new :text => value, :phrase => phrase, :locale => locale
            translation.save ? saved += 1 : unsaved +=1
          else
            puts "[ERROR] Key '#{key}' was found in #{locale_name}.yml but #{Tolk::Locale.primary_language_name} translation is missing"
          end
        end

        puts "[INFO] Imported #{saved} keys, not imported #{unsaved} from #{locale_name}.yml"
      end

    end

    def read_locale_file
      locale_file = "#{self.locales_config_path}/#{self.name}.yml"
      raise "Locale file #{locale_file} does not exists" unless File.exists?(locale_file)

      self.class.flat_hash(YAML::load(IO.read(locale_file))[self.name])
    end

  end
end