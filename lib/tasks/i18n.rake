# http://mentalized.net/journal/2009/08/10/find_missing_translations_in_your_rails_application/

namespace :i18n do

  def collect_keys(scope, translations)
    full_keys = []
    translations.to_a.each do |key, translations|
      new_scope = scope.dup << key
      if translations.is_a?(Hash)
        full_keys += collect_keys(new_scope, translations)
      else
        full_keys << new_scope.join('.')
      end
    end
    return full_keys
  end

  desc "Find and list translation keys that do not exist in all locales"
  task :missing_keys => :environment do

    # Make sure we’ve loaded the translations
    I18n.backend.send(:init_translations)
    puts "#{I18n.available_locales.size} #{I18n.available_locales.size == 1 ? 'locale' : 'locales'} available: #{I18n.available_locales.to_sentence}"

    # Get all keys from all locales
    all_keys = I18n.backend.send(:translations).collect do |check_locale, translations|
      collect_keys([], translations).sort
    end.flatten.uniq
    puts "#{all_keys.size} #{all_keys.size == 1 ? 'unique key' : 'unique keys'} found."

    missing_keys = {}
    all_keys.each do |key|

      I18n.available_locales.each do |locale|
        I18n.locale = locale
        begin
          result = I18n.translate(key, :raise => true)
        rescue I18n::MissingInterpolationArgument
          # noop
        rescue I18n::MissingTranslationData
          if missing_keys[key]
            missing_keys[key] << locale
          else
            missing_keys[key] = [locale]
          end
        end
      end
    end

    puts "#{missing_keys.size} #{missing_keys.size == 1 ? 'key is missing' : 'keys are missing'} from one or more locales:"
    missing_keys.keys.sort.each do |key|
      puts "'#{key}': Missing from #{missing_keys[key].join(', ')}"
    end

  end

  desc "Find and list translation keys found in the app but not in all of the locales"
  task :missing_keys2 => :environment do
    # Make sure we’ve loaded the translations
    I18n.backend.send(:init_translations)
    puts "#{I18n.available_locales.size} #{I18n.available_locales.size == 1 ? 'locale' : 'locales'} available: #{I18n.available_locales.to_sentence}"

    # Get all keys from all locales
    available_keys = I18n.backend.send(:translations).collect do |check_locale, translations|
      collect_keys([], translations).sort
    end.flatten.uniq
    
    # Get all keys used in app
    Dir[RAILS_ROOT + '/app/**/*'].each do |path|
      missing = []
      unless File.directory?(path)
        File.read(path).scan(/I18n\.t\(['"](.+?)['"]/).map { |s| s.first }.each do |key|
          unless available_keys.include?(key)
            if possible_match = available_keys.detect { |k| k[0...key.length] == key } and possible_match =~ /\.one$|\.other$|\.are$|\.is$|^relationships\.names\./
              # pass
            else
              missing << key
            end
          end
        end
        if missing.any?
          puts path
          puts missing
          puts
        end
      end
    end
  end
  
  desc "Find and list translation keys that aren't properly inserted (possibly) in the ERB views"
  task :misused_keys => :environment do
    # Get all keys used in app
    misused_keys = []
    Dir[RAILS_ROOT + '/app/views/**/*.erb'].each do |path|
      matches = []
      unless File.directory?(path)
        File.read(path).scan(/.{0,11}I18n\.t\(/).map { |s| s.to_s }.each do |match|
          unless match =~ /<%= I18n| => I18n|link_to I18n|[\[\(]I18n|\+\s?I18n|, I18n|submit(_tag)? I18n|rescue I18n| [\?:] I18n|_to_remote I18n|_function I18n|\.label I18n|#\{I18n/
            matches << match
          end
        end
        if matches.any?
          puts path
          puts matches
          puts
        end
      end
    end
  end
end
