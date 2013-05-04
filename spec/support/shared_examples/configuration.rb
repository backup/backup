# encoding: utf-8

module Backup
shared_examples 'a class that includes Configuration::Helpers' do

  describe 'setting defaults' do
    let(:accessor_names) {
      (described_class.instance_methods - Class.methods).
      select {|method| method.to_s.end_with?('=') }.
      map {|name| name.to_s.chomp('=') }
    }

    before do
      names = accessor_names
      described_class.defaults do |klass|
        names.each do |name|
          klass.send("#{ name }=", "default_#{ name }")
        end
      end
    end

    after { described_class.clear_defaults! }

    it 'allows accessors to be configured with default values' do
      db = described_class.new(model)
      accessor_names.each do |name|
        expect( db.send(name) ).to eq "default_#{ name }"
      end
    end

    it 'allows defaults to be overridden' do
      names = accessor_names
      db = described_class.new(model) do |klass|
        names.each do |name|
          klass.send("#{ name }=", "new_#{ name }")
        end
      end
      names.each do |name|
        expect( db.send(name) ).to eq "new_#{ name }"
      end
    end

  end # describe 'setting defaults'

end
end
