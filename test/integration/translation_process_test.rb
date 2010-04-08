require 'test_helper'

class TranslationProcessTest < ActionController::IntegrationTest
  setup :setup_locales

  def test_adding_locale
    assert_difference('Tolk::Locale.count') { add_locale 'pirate' }
  end

  def test_adding_missing_translations_and_updating_translations
    locale = add_locale('pirate')
    assert locale.translations.empty?

    # Adding a new translation
    pirate_url = tolk_locale_url(locale)
    visit pirate_url
    fill_in 'translations][][text]', :with => "Dead men don't bite"
    click_button 'Update all'

    assert_equal current_url, pirate_url
    assert_equal 1, locale.translations.count

    # Updating the translation added above
    click_link 'Existing translations'
    assert_contain "Dead men don't bite"

    fill_in 'translations][][text]', :with => "Arrrr!"
    click_button 'Update all'

    assert_equal current_url, all_tolk_locale_url(locale)
    assert_equal 1, locale.translations.count
    assert_equal 'Arrrr!', locale.translations(true).first.text
  end

  private

  def add_locale(name)
    visit tolk_root_path
    fill_in 'tolk_locale_name', :with => name
    click_button 'Add'

    Tolk::Locale.find_by_name!(name)
  end

  def setup_locales
    Tolk::Locale.delete_all
    Tolk::Translation.delete_all
    Tolk::Phrase.delete_all

    Tolk::Locale.locales_config_path = RAILS_ROOT + "/test/locales/sync"
    Tolk::Locale.primary_locale_name = 'en'
    Tolk::Locale.primary_locale(true)

    Tolk::Locale.sync!
  end
end
