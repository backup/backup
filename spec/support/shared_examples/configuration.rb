# encoding: utf-8

shared_examples 'a class that includes Configuration::Helpers' do

  describe 'setting defaults' do
    let(:accessor_names) {
      (described_class.instance_methods - Class.methods).
      select {|method| method.to_s.end_with?('=') }.
      map {|name| name.to_s.chomp('=') }
    }

    before do
      overrides = respond_to?(:default_overrides) ? default_overrides : {}
      names = accessor_names
      described_class.defaults do |klass|
        names.each do |name|
          val = overrides[name] || "default_#{ name }"
          klass.send("#{ name }=", val)
        end
      end
    end

    after { described_class.clear_defaults! }

    it 'allows accessors to be configured with default values' do
      overrides = respond_to?(:default_overrides) ? default_overrides : {}
      klass = respond_to?(:model) ?
          described_class.new(model) : described_class.new
      accessor_names.each do |name|
        expected = overrides[name] || "default_#{ name }"
        expect( klass.send(name) ).to eq expected
      end
    end

    it 'allows defaults to be overridden' do
      overrides = respond_to?(:new_overrides) ? new_overrides : {}
      names = accessor_names
      block = Proc.new do |klass|
        names.each do |name|
          val = overrides[name] || "new_#{ name }"
          klass.send("#{ name }=", val)
        end
      end
      klass = respond_to?(:model) ?
          described_class.new(model, &block) : described_class.new(&block)
      names.each do |name|
        expected = overrides[name] || "new_#{ name }"
        expect( klass.send(name) ).to eq expected
      end
    end

  end # describe 'setting defaults'

end
