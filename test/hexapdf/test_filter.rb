# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/filter'
require 'stringio'
require 'tempfile'

describe HexaPDF::Filter do
  include TestHelper

  before do
    @str = ''
    40.times { @str << [rand(2**32)].pack('N') }
  end

  describe "source_from_string" do
    it "doesn't modify the given string" do
      str = @str.dup
      HexaPDF::Filter.source_from_string(@str).resume.slice!(0, 10)
      assert_equal(str, @str)
    end

    it "returns the whole string" do
      assert_equal(@str, collector(HexaPDF::Filter.source_from_string(@str)))
    end
  end

  describe "source_from_io" do
    before do
      @io = StringIO.new(@str.dup)
    end

    it "converts an IO into a source via #source_from_io" do
      assert_equal(@str, collector(HexaPDF::Filter.source_from_io(@io)))

      assert_equal(@str, collector(HexaPDF::Filter.source_from_io(@io, pos: -10)))
      assert_equal(@str[10..-1], collector(HexaPDF::Filter.source_from_io(@io, pos: 10)))
      assert_equal("", collector(HexaPDF::Filter.source_from_io(@io, pos: 200)))

      assert_equal("", collector(HexaPDF::Filter.source_from_io(@io, length: 0)))
      assert_equal(@str[0...100], collector(HexaPDF::Filter.source_from_io(@io, length: 100)))
      assert_equal(@str, collector(HexaPDF::Filter.source_from_io(@io, length: -15)))
      assert_equal(100, HexaPDF::Filter.source_from_io(@io, length: 100).length)

      assert_equal(@str, collector(HexaPDF::Filter.source_from_io(@io, chunk_size: -15)))
      assert_equal(@str, collector(HexaPDF::Filter.source_from_io(@io, chunk_size: 0)))
      assert_equal(@str, collector(HexaPDF::Filter.source_from_io(@io, chunk_size: 100)))
      assert_equal(@str, collector(HexaPDF::Filter.source_from_io(@io, chunk_size: 200)))

      assert_equal(@str[0...20], collector(HexaPDF::Filter.source_from_io(@io, length: 20, chunk_size: 100)))
      assert_equal(@str[20...40], collector(HexaPDF::Filter.source_from_io(@io, pos: 20, length: 20, chunk_size: 100)))
      assert_equal(@str[20...40], collector(HexaPDF::Filter.source_from_io(@io, pos: 20, length: 20, chunk_size: 5)))
    end

    it "fails if not all requested bytes could be read" do
      assert_raises(HexaPDF::Error) do
        collector(HexaPDF::Filter.source_from_io(@io, length: 200))
      end
    end
  end

  describe "source_from_file" do
    before do
      @file = Tempfile.new('hexapdf-filter')
      @file.write(@str)
      @file.close
    end

    after do
      @file.unlink
    end

    it "converts the file into a source fiber" do
      assert_equal(@str, collector(HexaPDF::Filter.source_from_file(@file.path)))
      assert_equal(@file.size, HexaPDF::Filter.source_from_file(@file.path).length)

      assert_equal(@str[100..-1], collector(HexaPDF::Filter.source_from_file(@file.path, pos: 100)))
      assert_equal(@str[100..-1].length, HexaPDF::Filter.source_from_file(@file.path, pos: 100).length)

      assert_equal(@str[50...100], collector(HexaPDF::Filter.source_from_file(@file.path, pos: 50, length: 50)))
      assert_equal(50, HexaPDF::Filter.source_from_file(@file.path, length: 50).length)
    end

    it "fails if more bytes are requested than stored in the file" do
      assert_raises(HexaPDF::Error) do
        collector(HexaPDF::Filter.source_from_file(@file.path, length: 200))
      end
    end
  end

  it "collects the binary string from a source via #string_from_source" do
    source = HexaPDF::Filter.source_from_io(StringIO.new(@str), chunk_size: 50)
    result = HexaPDF::Filter.string_from_source(source)
    assert_equal(@str, result)
    assert_equal(Encoding::BINARY, result.encoding)
  end
end