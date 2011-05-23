module Tolk
  class Phrase < Ohm::Model##ActiveRecord::Base
    ## set_table_name "tolk_phrases"

    ##validates_uniqueness_of :key

    # if you want to search by attribute add "index"for  that
    # Tolk::Phrase.find :pkey => "key"
    # Dont use "key" as attribute, not even alias nor method, because Ohm mysteriously will fail
    attribute :pkey
    index :pkey

    #alias :key :pkey

    cattr_accessor :per_page
    self.per_page = 30

    ##has_many :translations, :class_name => 'Tolk::Translation', :dependent => :destroy do
    collection :translations, Tolk::Translation
    # TODO 1. dependent translations destroy on phrase destroy

##      def primary
##        to_a.detect {|t| t.locale_id == Tolk::Locale.primary_locale.id}
##      end
##      def for(locale)
##        to_a.detect {|t| t.locale_id == locale.id}
##      end
    # compared to above
    class Ohm::Model::Set
      def primary
        to_a.detect{|t|t.locale_id == Tolk::Locale.primary_locale.id}
      end

      def for(locale)
        to_a.detect {|t| t.locale_id == locale.id}
      end
    end


    ##end

    attr_accessor :translation

    def validate
      assert_unique :pkey
    end

    # Ohm: Added to help with direct queries
    def self.count
      self.all.size
    end

    # Ohm: Extend :)
    def self.scoped
      puts "? not needed ?"
    end
  end
end
