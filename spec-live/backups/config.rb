##
# Configuration Defaults

Backup::Storage::Local.defaults do |storage|
  storage.path = SpecLive::TMP_PATH
  storage.keep = 2
end

Backup::Encryptor::GPG.defaults do |enc|
  enc.gpg_homedir = File.join(SpecLive::TMP_PATH, 'gpg_home_tmp')
end

##
# Load the Models, unless h_set_single_model() is being used.
if SpecLive.load_models
  instance_eval File.read(File.join(File.dirname(__FILE__), 'models.rb'))
end
