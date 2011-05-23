module Tolk
  class LocalesController < Tolk::ApplicationController
    before_filter :find_locale, :only => [:show, :all, :update, :updated]
    before_filter :ensure_no_primary_locale, :only => [:all, :update, :show, :updated]

    def index
      @locales = Tolk::Locale.secondary_locales
    end
  
    def show
      respond_to do |format|
        format.html do
          @phrases = @locale.phrases_without_translation.paginate(:page => params[:page])
        end
        format.atom { @phrases = @locale.phrases_without_translation(params[:page], :per_page => 50) }
        format.yml { render :text => @locale.to_hash.ya2yaml(:syck_compatible => true) }
      end
    end

    def update
      ##@locale.translations_attributes = params[:translations]
      ##@locale.save
      created, updated = 0,0
      for translation in params[:translations]
        text = translation[:text].to_s.strip
        if text.present?
          if translation[:id].present? # edit
            translation = Tolk::Translation[translation[:id]]
            translation.text = text
            translation.primary_updated = true
            updated+=1
          else
            translation = Tolk::Translation.new :text => text, :phrase => Tolk::Phrase[translation[:phrase_id]], :locale => @locale
            translation.primary_updated = false
            created+=1
          end
          translation.save
        end

      end
      flash[:notice] = "Save successful, created: #{created}, updated: #{updated}"
      @locale.save
      redirect_to request.referrer
    end

    def all
      @phrases = @locale.phrases_with_translation.paginate(:page => params[:page])
    end

    def updated
      remove_invalid_translations_from_target
      @phrases = @locale.phrases_with_updated_translation.paginate(:page => params[:page])
      render :all
    end

    def create
      Tolk::Locale.create(params[:tolk_locale])
      Tolk::Locale.primary_locale(true) # Reload redis info
      redirect_to :action => :index
    end

    private

    def find_locale
      @locale = Tolk::Locale.find(:name =>params[:id]).first
    end

    def remove_invalid_translations_from_target
      @locale.translations.proxy_target.each do |t|
        unless t.valid?
          self.translations.proxy_target.delete(t)
        else
          t.updated_at = Time.current # Silly hax to fool autosave into saving the record
        end
      end
    end
  end
end
