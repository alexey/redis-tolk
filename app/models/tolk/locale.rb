module Tolk
  class Locale < Ohm::Model ##ActiveRecord::Base
    ### Everything double commented is original declaration

    ##set_table_name "tolk_locales"

    # Define attributes to use with Ohm
    attribute :name
    index :name

    # NOTE: Locale.find :name =>"some" is like :all
    MAPPING = {
      'ar'    => 'Arabic',
      'bs'    => 'Bosnian',
      'bt'    => 'Bulgarian',
      'ca'    => 'Catalan',
      'cz'    => 'Czech',
      'da'    => 'Danish',
      'de'    => 'German',
      'dsb'   => 'Lower Sorbian',
      'el'    => 'Greek',
      'en'    => 'English',
      'es'    => 'Spanish',
      'et'    => 'Estonian',
      'fa'    => 'Persian',
      'fi'    => 'Finnish',
      'fr'    => 'French',
      'he'    => 'Hebrew',
      'hr'    => 'Croatian',
      'hsb'   => 'Upper Sorbian',
      'hu'    => 'Hungarian',
      'id'    => 'Indonesian',
      'is'    => 'Icelandic',
      'it'    => 'Italian',
      'jp'    => 'Japanese',
      'ko'    => 'Korean',
      'lo'    => 'Lao',
      'lt'    => 'Lithuanian',
      'lv'    => 'Latvian',
      'mk'    => 'Macedonian',
      'nl'    => 'Dutch',
      'no'    => 'Norwegian',
      'pl'    => 'Polish',
      'pt-BR' => 'Portuguese (Brazilian)',
      'pt-PT' => 'Portuguese (Portugal)',
      'ro'    => 'Romanian',
      'ru'    => 'Russian',
      'se'    => 'Swedish',
      'sk'    => 'Slovak',
      'sl'    => 'Slovenian',
      'sr'    => 'Serbian',
      'sw'    => 'Swahili',
      'th'    => 'Thai',
      'tr'    => 'Turkish',
      'uk'    => 'Ukrainian',
      'vi'    => 'Vietnamese',
      'zh-CN' => 'Chinese (Simplified)',
      'zh-TW' => 'Chinese (Traditional)'
    }

    ##has_many :phrases, :through => :translations, :class_name => 'Tolk::Phrase'
    collection :phrases, Tolk::Phrase

    ##has_many :translations, :class_name => 'Tolk::Translation', :dependent => :destroy
    collection :translations, Tolk::Translation

    ##accepts_nested_attributes_for :translations, :reject_if => proc { |attributes| attributes['text'].blank? }
    ## to controller >>> before_validation :remove_invalid_translations_from_target, :on => :update

    cattr_accessor :locales_config_path
    self.locales_config_path = "#{Rails.root}/config/locales"

    cattr_accessor :primary_locale_name
    self.primary_locale_name = I18N_LOCALE.to_s ##I18n.default_locale.to_s

    include Tolk::Sync
    include Tolk::Import

    ##validates_uniqueness_of :name
    ##validates_presence_of :name
    # strange not working
#    def validate
#      assert_present :name
#      assert_unique :name
#    end

    cattr_accessor :special_prefixes
    self.special_prefixes = ['activerecord.attributes']

    cattr_accessor :special_keys
    self.special_keys = ['activerecord.models']

    class << self

      #for console testing when added same locales
      def remove_dups

      end

      def primary_locale(reload = false)
        @_primary_locale = nil if reload
        @_primary_locale ||= begin
          raise "Hey pizduk, primary locale is not set. Please set Locale.primary_locale_name in your application's config file" unless self.primary_locale_name
          ##find_or_create_by_name(self.primary_locale_name)
          setlocale = Locale.find(:name =>self.primary_locale_name).first
          if setlocale.blank?
            setlocale = Locale.create :name => self.primary_locale_name
          end
          setlocale
        end
      end

      def primary_language_name
        primary_locale.language_name
      end

      def secondary_locales
        ##all - [primary_locale]
        ary = []
        for locale in all
          ary << locale if locale.id != primary_locale.id
        end
        ary
      end

      def dump_all(to = self.locales_config_path)
        puts "[INFO] Dumping translations nah"
        secondary_locales.each do |locale|
          filename = "#{to}/#{locale.name}.yml"
          puts "[INFO] Outputting *#{locale.name}* to file: #{filename}"
          File.open(filename, "w+") do |file|
            data = locale.to_hash
            data.respond_to?(:ya2yaml) ? file.write(data.ya2yaml(:syck_compatible => true)) : YAML.dump(locale.to_hash, file)
          end
        end
      end

      def special_key_or_prefix?(prefix, key)
        self.special_prefixes.include?(prefix) || self.special_keys.include?(key)
      end

      PLURALIZATION_KEYS = ['none', 'one', 'two', 'few', 'many', 'other']
      def pluralization_data?(data)
        keys = data.keys.map(&:to_s)
        keys.all? {|k| PLURALIZATION_KEYS.include?(k) }
      end
    end

    def has_updated_translations?
      ##translations.count(:conditions => {:'tolk_translations.primary_updated' => true}) > 0
      translations.find(:primary_updated => true).size > 0
    end

    def phrases_with_translation
      ##find_phrases_with_translations(page, :'tolk_translations.primary_updated' => false)
      find_phrases_with_translations(:'primary_updated' => false)
    end

    def phrases_with_updated_translation
      ##find_phrases_with_translations(page, :'tolk_translations.primary_updated' => true)
      find_phrases_with_translations('primary_updated' => true)
    end

    def count_phrases_without_translation
##      existing_ids = self.translations.all(:select => 'tolk_translations.phrase_id').map(&:phrase_id).uniq
##      Tolk::Phrase.count - existing_ids.count
      existing_ids = self.translations.map(&:phrase_id).uniq
      Tolk::Phrase.count - existing_ids.size
    end

    def phrases_without_translation
      ##phrases = Tolk::Phrase.scoped(:order => 'tolk_phrases.key ASC')
      pre_phrases = Tolk::Phrase.all.sort(:by => "pkey", :order => 'ASC',:locale => self) #
      phrases = []

#      existing_ids = self.translations.all(:select => 'tolk_translations.phrase_id').map(&:phrase_id).uniq
#      phrases = phrases.scoped(:conditions => ['tolk_phrases.id NOT IN (?)', existing_ids]) if existing_ids.present?
      existing_ids = self.translations.map(&:phrase_id).uniq
      # next thing will create array of unique elements from pre_phrases and existing ids
      if existing_ids.present?
        not_exist = (pre_phrases.map(&:id) | existing_ids) - (pre_phrases.map(&:id) & existing_ids)
        for nex in not_exist
          phrases << Tolk::Phrase[nex]
        end
      end

      ##result = phrases.paginate({:page => page}.merge(options))
      phrases

      ## not having that .. Tolk::Phrase.send :preload_associations, result, :translations

    end

    def search_phrases(query, scope, page = nil, options = {})
      return [] unless query.present?

##      translations = case scope
##      when :origin
##        Tolk::Locale.primary_locale.translations.containing_text(query)
##      else # :target
##       self.translations.containing_text(query)
##      end
      # TODO upgrade next line to above filter
      translations = self.translations.find(:text => query) # regexp wont work here in any way, except manual map of text and search thru array
##      phrases = Tolk::Phrase.scoped(:order => 'tolk_phrases.key ASC')
##      phrases = phrases.scoped(:conditions => ['tolk_phrases.id IN(?)', translations.map(&:phrase_id).uniq])
##      phrases.paginate({:page => page}.merge(options))
      phrases = Tolk::Phrase.all.sort :by => 'tolk_phrases'
      new_phrases = []
      for phrase in phrases
        new_phrases << phrase if translations.map(&:phrase_id).uniq.include?(phrase.id)
      end

      ##phrases.paginate({:page => page}.merge(options))
      new_phrases

    end
    
    def search_phrases_without_translation(query, page = nil, options = {})
      return phrases_without_translation unless query.present?
      
      ##phrases = Tolk::Phrase.scoped(:order => 'tolk_phrases.key ASC')
      phrases = Tolk::Phrase.all.sort :by => 'tolk_phrases'

      ##found_translations_ids = Tolk::Locale.primary_locale.translations.all(:conditions => ["tolk_translations.text LIKE ?", "%#{query}%"], :select => 'tolk_translations.phrase_id').map(&:phrase_id).uniq
      found_translations_ids = []
      translations = Tolk::Locale.primary_locale_name.translations
      for tr in translations
        found_translations_ids << tr.phrase_id if tr.containing_text(query)
      end

      ##existing_ids = self.translations.all(:select => 'tolk_translations.phrase_id').map(&:phrase_id).uniq
      existing_ids = self.translations.map(&:phrase_id).uniq

      ##phrases = phrases.scoped(:conditions => ['tolk_phrases.id NOT IN (?) AND tolk_phrases.id IN(?)', existing_ids, found_translations_ids]) if existing_ids.present?
      new_phrases = []
      if existing_ids.present?
        for phase in phrases
          new_phrases << phase if !existing_ids.include?(phase.id) && found_translations_ids.include?(phase.id)
        end
      end

      ##result = phrases.paginate({:page => page}.merge(options))
      result = phrases
      ## Tolk::Phrase.send :preload_associations, result, :translations
      result
    end

    def to_hash
      { name => translations.each_with_object({}) do |translation, locale|
        if translation.phrase.pkey.include?(".")
          locale.deep_merge!(unsquish(translation.phrase.pkey, translation.value))
        else
          locale[translation.phrase.pkey] = translation.value
        end
      end }
    end

    def to_param
      name.parameterize
    end

    def primary?
      name == self.class.primary_locale_name
    end

    def language_name
      MAPPING[self.name] || self.name
    end

    def [](pkey)
##      if phrase = Tolk::Phrase.find_by_key(key)
##        t = self.translations.find_by_phrase_id(phrase.id)
##        t.text if t
##      end
      if phrase = Tolk::Phrase.find(:pkey => pkey).first
        t = self.translations.find(:phrase_id => phrase.id).first
        t.text if t
      end
    end

    def translations_with_html
      ##translations = self.translations.all(:conditions => "tolk_translations.text LIKE '%>%' AND
      ##  tolk_translations.text LIKE '%<%' AND tolk_phrases.key NOT LIKE '%_html'", :joins => :phrase)
      translations = []
      for tr in self.translations.all
        translations << tr if tr.text =~ /</ && tr.text =~ />/ && tr.pkey !=~ /(_html)\b$/i
      end
      # not available for Ohm.. Translation.send :preload_associations, translations, :phrase
      translations
    end

    private
    # moved to translation controller
##    def remove_invalid_translations_from_target
##      self.translations.proxy_target.each do |t|
##        unless t.valid?
##          self.translations.proxy_target.delete(t)
##        else
##          t.updated_at = Time.current # Silly hax to fool autosave into saving the record
##        end
##      end
##
##      true
##    end

    def find_phrases_with_translations(conditions = {})
##      result = Tolk::Phrase.paginate(:page => page,
##        :conditions => { :'tolk_translations.locale_id' => self.id }.merge(conditions),
##        :joins => :translations, :order => 'tolk_phrases.key ASC')
      translations = Tolk::Translation.find({:locale_id => self.id}.merge(conditions))#.map(&:id)
      result = []
      for translation in translations
        result << translation.phrase
      end
      # TODO paginatioh,order,page

      # no method for Ohm> Tolk::Phrase.send :preload_associations, result, :translations

##      result.each do |phrase|
##        phrase.translation = phrase.translations.for(self)
##      end
      result.each do |phrase|
        phrase.translation = phrase.translations.for(self)
      end
      result
    end

    def unsquish(string, value)
      if string.is_a?(String)
        unsquish(string.split("."), value)
      elsif string.size == 1
        { string.first => value }
      else
        key  = string[0]
        rest = string[1..-1]
        { key => unsquish(rest, value) }
      end
    end
  end
end
