##
# Configuration Defaults
#
# Note that once config.rb has been loaded once and class defaults are set,
# there's nothing clearing these between each test. Keep this in mind, as this
# file will be loaded for every call to h_set_trigger() or h_set_single_model().
# While not a problem, this wouldn't happen for a normal `backup perform ...`.

Backup::Storage::Local.defaults do |storage|
  storage.path = SpecLive::TMP_PATH
  storage.keep = 2
end

# SSH operations can be tested against 'localhost'
# To do this, in the config.yml file:
# - set username/password for your current user
# - set ip to 'localhost'
# Although optional, it's recommended you set the 'path'
# to the same path as Backup::SpecLive::TMP_PATH
# i.e. '/absolute/path/to/spec-live/tmp'
# This way, cleaning the "remote path" can be skipped.
Backup::Storage::SCP.defaults do |storage|
  opts = SpecLive::CONFIG['storage']['scp']

  storage.username = opts['username']
  storage.password = opts['password']
  storage.ip       = opts['ip']
  storage.port     = opts['port']
  storage.path     = opts['path']
  storage.keep     = 2
end

Backup::Storage::Dropbox.defaults do |storage|
  opts = SpecLive::CONFIG['storage']['dropbox']

  storage.api_key     = opts['api_key']
  storage.api_secret  = opts['api_secret']
  storage.access_type = opts['access_type']
  storage.path        = opts['path']
  storage.keep        = 2
end

Backup::Notifier::Mail.defaults do |notifier|
  opts = SpecLive::CONFIG['notifier']['mail']

  notifier.on_success           = true
  notifier.on_warning           = true
  notifier.on_failure           = true

  notifier.delivery_method      = opts['delivery_method']
  notifier.from                 = opts['from']
  notifier.to                   = opts['to']
  notifier.address              = opts['address']
  notifier.port                 = opts['port'] || 587
  notifier.domain               = opts['domain']
  notifier.user_name            = opts['user_name']
  notifier.password             = opts['password']
  notifier.authentication       = opts['authentication'] || 'plain'
  notifier.enable_starttls_auto = opts['enable_starttls_auto'] || true
  notifier.sendmail             = opts['sendmail']
  notifier.sendmail_args        = opts['sendmail_args']
  notifier.mail_folder          = SpecLive::TMP_PATH
end

Backup::Syncer::Cloud::S3.defaults do |s3|
  opts = SpecLive::CONFIG['syncer']['cloud']['s3']

  s3.access_key_id     = opts['access_key_id']
  s3.secret_access_key = opts['secret_access_key']
  s3.bucket            = opts['bucket']
  s3.region            = opts['region']
  s3.mirror            = true
end

Backup::Encryptor::GPG.defaults do |enc|
  enc.gpg_homedir = File.join(SpecLive::TMP_PATH, 'gpg_home_tmp')
end

##
# Load the Models, unless h_set_single_model() is being used.
if SpecLive.load_models
  instance_eval File.read(File.join(File.dirname(__FILE__), 'models.rb'))
end
