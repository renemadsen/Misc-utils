module MicrotingUtils::Comparison
  module Diffable
    def diff(b)
      Diff.new(self, b)
    end

    # Create a hash that maps elements of the array to arrays of indices
    # where the elements are found.

    def reverse_hash(range = (0...self.length))
      revmap = {}
      range.each { |i|
        elem = self[i]
        if revmap.has_key? elem
          revmap[elem].push i
        else
          revmap[elem] = [i]
        end
      }
      return revmap
    end

    def replacenextlarger(value, high = nil)
      high ||= self.length
      if self.empty? || value > self[-1]
        push value
        return high
      end
      # binary search for replacement point
      low = 0
      while low < high
        index = (high+low)/2
        found = self[index]
        return nil if value == found
        if value > found
          low = index + 1
        else
          high = index
        end
      end

      self[low] = value
      # $stderr << "replace #{value} : 0/#{low}/#{init_high} (#{steps} steps) (#{init_high-low} off )\n"
      # $stderr.puts self.inspect
      #gets
      #p length - low
      return low
    end

    def patch(diff)
      newary = nil
      if diff.difftype == String
        newary = diff.difftype.new('')
      else
        newary = diff.difftype.new
      end
      ai = 0
      bi = 0
      diff.diffs.each { |d|
        d.each { |mod|
          case mod[0]
            when '-'
              while ai < mod[1]
                newary << self[ai]
                ai += 1
                bi += 1
              end
              ai += 1
            when '+'
              while bi < mod[1]
                newary << self[ai]
                ai += 1
                bi += 1
              end
              newary << mod[2]
              bi += 1
            else
              raise "Unknown diff action"
          end
        }
      }
      while ai < self.length
        newary << self[ai]
        ai += 1
        bi += 1
      end
      return newary
    end
  end
end

class Array
  include MicrotingUtils::Comparison::Diffable
end

class String
  include MicrotingUtils::Comparison::Diffable
end

