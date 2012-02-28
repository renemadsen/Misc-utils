#require "exceptions/core_error"
require "rexml/document"
require "microting_utils/comparison/diff"

module MicrotingUtils::Comparison
  module Comparison

    IGNORE_CONTENT = '++--ignore--++'

    def clone_hash_attributes hash
      cloned_values = {}
      return if hash.nil?
      hash.each { |key, value|
        if value.class == Hash
          cloned_values[key] = clone_hash_attributes(value)
        else
          cloned_values[key] = value.respond_to?(:to_s) ? value.to_s : value.inspect
        end
      }
      cloned_values
    end

# If 'accept_extra_modifications' is true it will not validate the modifications are ONLY the ones passed inside 'expected_modifications',
# in other words the model can have more modifications then the ones specified. If 'accept_extra_modifications' the
# model can only have the amount of modifications specifie in 'expected_modifications'
    def check_model_modifications_after_block(model, expected_modifications, accept_extra_modifications = false, &block)
      old_values = clone_hash_attributes(model.attributes)
      yield if block
      new_values = clone_hash_attributes(model.attributes)
      compare_hashes(old_values, new_values, expected_modifications, accept_extra_modifications, false)
    end

    def compare_hashes(old_values, new_values, expected_modifications, accept_extra_modifications = false, need_cloning = true)
      if need_cloning
        old_values = clone_hash_attributes old_values
        new_values = clone_hash_attributes new_values
      end
      if !old_values.nil?
        #remove the equal values
        new_values.delete_if { |key, value| old_values.has_key?(key) and value.to_s == old_values[key].to_s }
      end
      #make sure all the expected values were achieved
      expected_modifications.each do |key, value|
        new_value = nil
        if new_values.has_key?(key.to_s)
          new_value = new_values[key.to_s]
        elsif new_values.has_key?(key.to_sym)
          new_value = new_values[key.to_sym]
        else
          msg = "Key '#{key.inspect}'  not present in the modifications.\ndetails: expected modifications \n #{expected_modifications.inspect}\n new values : #{new_values.inspect}"
          if self.respond_to?("flunk", true)
            flunk msg
          else
            raise Exception, msg
          end
        end


        if value.is_a?(Hash)
          begin
            compare_hashes(old_values.nil? ? nil : old_values[key], new_value, value, false, false)
          rescue Exception => e
            raise if !e.is_a?(Exception)
            msg = "Inside hash '#{new_value}' , " + e.message
            raise Exception, msg
          end
        else
          if value != IGNORE_CONTENT
            value_comparable = value.respond_to?(:to_s) ? value.to_s : value.inspect
            new_value_comparable = new_value.respond_to?(:to_s) ? new_value.to_s : new_value.inspect
            check_equal value_comparable, new_value_comparable, "the content of key '#{key}' is not expected"
          end
        end
      end
      # check if there are more modifications then the ones provided
      if !accept_extra_modifications
        new_values.delete_if { |key, value|
          expected_modifications.has_key?(key.to_s) or expected_modifications.has_key?(key.to_sym)
        }
        check_equal 0, new_values.length, "There are more modifications then the expected >>> #{new_values.inspect} "
      end

    end

    def check_model_modifications(original, modified, modifications)
      compare_hashes(original.attributes,
                     modified.attributes,
                     modifications)
    end

    def compare_xml_strings(modified, expected, ignore_xpath = [])
      modified_rexml = REXML::Document.new modified
      expected_rexml = REXML::Document.new expected
      compare_xml_elements(modified_rexml, expected_rexml, ignore_xpath)
    end

    # This compare two parsed Rexml content. It evaluates as xml meaning, so whitspaces, attributes order, etc are not considered.
    def compare_xml_elements modified, expected, ignore_xpath = []
      return if modified.nil? and expected.nil?
      begin
        check_equal expected.xpath, modified.xpath, 'Different xpath'
        #ignore the other comparisons if it's included in the ignore group
        return if ignore_xpath.include?(expected.xpath)

        diff_string_array modified.attributes.keys.sort, expected.attributes.keys.sort
        diff_string_array convert_to_string_array(modified.attributes.values), convert_to_string_array(expected.attributes.values)
        unless expected.text.blank? and modified.text.blank?
          check_equal expected.text, modified.text
        end
        #, 'Different texts '
        check_equal expected.elements.size, modified.elements.size, 'Different children sizes '
        #the comparison need to occours in a sorted way due the ramdomness of hash :/
        expected_names = (expected.elements.to_a.collect { |ele| [ele.name+convert_to_string_array(ele.attributes.to_a).to_s+ele.object_id.to_s, ele] }).sort
        modified_names = (modified.elements.to_a.collect { |ele| [ele.name+convert_to_string_array(ele.attributes.to_a).to_s+ele.object_id.to_s, ele] }).sort
        expected_names.each_index { |i|
          compare_xml_elements modified_names[i][1], expected_names[i][1], ignore_xpath
        }
      rescue Exception => e
        if !e.message.start_with? '-->Failed'
          raise e.class, "-->Failed while comparing the modified:\n XPATH=#{modified.xpath}\n#{modified.inspect}\n\n against the expected:\n XPATH=#{expected.xpath}\n#{expected.inspect}\n\n Motive: \n #{e.message}"
        end
        raise
      end
    end

    def diff_string_array actual, expected
      p_diff = Diff.printable_diff(actual, expected)
      p_diff.each do |element|
        puts "\n\nError at line #{element[0]}"
        puts "modified   line: #{element[1]}"
        puts "original   line: #{element[2]}"
        puts "diferences line: #{element[3]}"
      end
      raise Exception, "Files are not equal" unless p_diff.empty?
    end

    #  This method compare two files or strings containing text content. In case the second parameter is not beeing passed
    #  it will try to check the context of the caller to figure out a file name and the folder of the caller
    #  to figureout where the file is located. So if the context ends in something like:
    #  file: desired-file-name.extension
    #  And the file is located in the same folder as the caller everything will work
    #  Check also:
    #     open_test_file
    def compare_docs(actual_doc, expected_doc=nil)
      require 'diff'

      case actual_doc
        when IO then
          actual = actual_doc.read.split("\n")
        when String then
          actual = actual_doc.split("\n")
        when Array then
          actual = actual_doc
        else
          raise Exception, "Invalid parameter"
      end

      file_opened = false
      begin
        case expected_doc
          when IO
            expected = expected_doc.read.split("\n")
          when String
            expected = expected_doc.split("\n")
          when Array then
            expected= expected_doc
          when nil then
            # in case the user do not pass the second parameter this will try to open a file based on the context
            expected_doc = open_test_file(3)
            expected = expected_doc.read.split("\n")
            file_opened = true
          else
            raise Exception, "Invalid parameter"
        end

        diff_string_array actual, expected
      ensure
        if file_opened and not expected_doc.closed?
          expected_doc.close
        end
      end
    end

    private

    def check_equal(expected, actual, message=nil)
      message = message || "The content #{actual.inspect} does not match with the expected #{expected.inspect}"
      if self.respond_to?("assert_equal", true)
        self.assert_equal(expected, actual, message)
      else
        raise Exception, message if expected != actual
      end
    end

    def convert_to_string_array rexml_array
      result = []
      rexml_array.each { |e|
        result << e.inspect
      }
      result.sort!
    end
  end
end
