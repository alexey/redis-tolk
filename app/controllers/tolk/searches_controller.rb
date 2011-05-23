module Tolk
  class SearchesController < Tolk::ApplicationController
    before_filter :find_locale
  
    def show
      @phrases = @locale.search_phrases(params[:q], params[:scope].to_sym, params[:page])
    end

    private

    def find_locale
      @locale = Tolk::Locale.find(:name => params[:locale]).first
    end
  end
end
