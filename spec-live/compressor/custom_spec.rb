# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Compressor::Custom' do

  def archive_file_for(model)
    File.join(
      Backup::SpecLive::TMP_PATH,
      "#{model.trigger}", model.time, "#{model.trigger}.tar"
    )
  end

  def archive_contents_for(model)
    archive_file = archive_file_for(model)
    %x{ tar -tvf #{archive_file} }
  end

  it 'should compress an archive' do
    model = h_set_trigger('compressor_custom_archive_local')
    model.perform!
    archive_file = archive_file_for(model)
    File.exist?(archive_file).should be_true
    archive_contents_for(model).should match(
      /compressor_custom_archive_local\/archives\/test_archive\.tar\.foo/
    )
    File.stat(archive_file).size.should be > 0
  end

end
