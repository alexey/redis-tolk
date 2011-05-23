module Tolk
  module Sync
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def sync!
        puts "[INFO] Running Tolk::Sync.sync!"
        sync_phrases(load_translations)
      end

      def load_translations
        I18n.available_locales # force load
        translations = flat_hash(I18n.backend.send(:translations)[primary_locale.name.to_sym])
        filter_out_i18n_keys(translations.merge(read_primary_locale_file))
      end

      def read_primary_locale_file
        primary_file = "#{self.locales_config_path}/#{self.primary_locale_name}.yml"
        File.exists?(primary_file) ? flat_hash(YAML::load(IO.read(primary_file))[self.primary_locale_name]) : {}
      end

      def flat_hash(data, prefix = '', result = {})
        data.each do |key, value|
          current_prefix = prefix.present? ? "#{prefix}.#{key}" : key

          if !value.is_a?(Hash) || Tolk::Locale.pluralization_data?(value)
            result[current_prefix] = value.respond_to?(:stringify_keys) ? value.stringify_keys : value
          else
            flat_hash(value, current_prefix, result)
          end
        end

        result.stringify_keys
      end

      private

      def sync_phrases(translations)
        primary_locale = self.primary_locale
        secondary_locales = self.secondary_locales
        puts "[INFO] Syncing primary locale: [#{primary_locale.name}] with secondary locales: [#{secondary_locales.map &:name}]"
        # Handle deleted phrases
        ##translations.present? ? Tolk::Phrase.destroy_all(["tolk_phrases.key NOT IN (?)", translations.keys]) : Tolk::Phrase.destroy_all
        tp = Tolk::Phrase.all
        if translations.present?
          for tolk_phrase in tp
            tp.delete(tolk_phrase) unless translations.keys.include?(tolk_phrase.pkey)
          end
        else
          tp.each {|t| tp.delete(t)} #Destroy all
        end

        phrases = Tolk::Phrase.all
        translations.each do |key, value|
          # Create phrase and primary translation if missing
          existing_phrase = phrases.detect {|p| p.pkey == key}
          unless existing_phrase
             existing_phrase = Tolk::Phrase.create(:pkey => key)
             if existing_phrase.errors.present?
               # TODO do something ?§
             end
          end
          translation = existing_phrase.translations.primary || Tolk::Translation.new(:phrase => existing_phrase, :locale => primary_locale) ##primary_locale.translations.build(:phrase_id => existing_phrase.id)
          old_text = translation.text
          translation.text = value

          ##if translation.changed? && !translation.new_record?
          if translation.text != old_text && !translation.new?
            # Set the primary updated flag if the primary translation has changed and it is not a new record.
            secondary_locales.each do |locale|
              if existing_translation = existing_phrase.translations.detect {|t| t.locale_id == locale.id }
                existing_translation.force_set_primary_update = true
                existing_translation.save
              end
            end
          end

          translation.primary = true
          translation.save
          if translation.errors
            # TODO do something ?
          end
        end
      end

      def filter_out_i18n_keys(flat_hash)
        flat_hash.reject { |key, value| key.starts_with? "i18n" }
      end
    end
  end
end
