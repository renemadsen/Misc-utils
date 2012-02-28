require 'microting_utils/comparison/diffable'

module MicrotingUtils::Comparison
  class Diff
    include MicrotingUtils::Comparison::Diffable

    VERSION = 0.3

    def Diff.lcs(a, b)
      astart = 0
      bstart = 0
      afinish = a.length-1
      bfinish = b.length-1
      mvector = []

      # First we prune off any common elements at the beginning
      while (astart <= afinish && bstart <= afinish && a[astart] == b[bstart])
        mvector[astart] = bstart
        astart += 1
        bstart += 1
      end

      # now the end
      while (astart <= afinish && bstart <= bfinish && a[afinish] == b[bfinish])
        mvector[afinish] = bfinish
        afinish -= 1
        bfinish -= 1
      end

      bmatches = b.reverse_hash(bstart..bfinish)
      thresh = []
      links = []

      (astart..afinish).each { |aindex|
        aelem = a[aindex]
        next unless bmatches.has_key? aelem
        k = nil
        bmatches[aelem].reverse.each { |bindex|
          if k && (thresh[k] > bindex) && (thresh[k-1] < bindex)
            thresh[k] = bindex
          else
            k = thresh.replacenextlarger(bindex, k)
          end
          links[k] = [(k==0) ? nil : links[k-1], aindex, bindex] if k
        }
      }

      if !thresh.empty?
        link = links[thresh.length-1]
        while link
          mvector[link[1]] = link[2]
          link = link[0]
        end
      end

      return mvector
    end

    def makediff(a, b)
      mvector = MicrotingUtils::Comparison::Diff.lcs(a, b)
      ai = bi = 0
      while ai < mvector.length
        bline = mvector[ai]
        if bline
          while bi < bline
            discardb(bi, b[bi])
            bi += 1
          end
          match(ai, bi)
          bi += 1
        else
          discarda(ai, a[ai])
        end
        ai += 1
      end
      while ai < a.length
        discarda(ai, a[ai])
        ai += 1
      end
      while bi < b.length
        discardb(bi, b[bi])
        bi += 1
      end
      match(ai, bi)
      1
    end

    def compactdiffs
      diffs = []
      @diffs.each { |df|
        i = 0
        curdiff = []
        while i < df.length
          whot = df[i][0]
          s = @isstring ? df[i][2].chr : [df[i][2]]
          p = df[i][1]
          last = df[i][1]
          i += 1
          while df[i] && df[i][0] == whot && df[i][1] == last+1
            s << df[i][2]
            last = df[i][1]
            i += 1
          end
          curdiff.push [whot, p, s]
        end
        diffs.push curdiff
      }
      return diffs
    end

    #
    #It returns an array containing the errors found like this:
    # [n][0]: the line number
    # [n][1]: the modified line being compared
    # [n][2]: the modifications needed in the line
    #
    #TODO handle error when the structure is different, i.e 2 totally different lines
    def self.printable_diff(modified, original)
      printable = []
      mask = ''
      l_number = 0
      modified_ = ''
      diff = Diff.new(modified, original)
      c_diffs = diff.compactdiffs
      #
      #Compactdiffs has the current structure:
      #  [0]difference 1
      #  ----[0]diff kind
      #  ----[1]start index
      #  ----[2]diff value
      #  ---------[0] diff value 1
      #  ---------[n] diff value N
      #  [N]difference N
      #  ----[0]diff kind
      #  ----[1]start index
      #  ----[2]diff value
      #  ---------[0] diff value 1
      #  ---------[n] diff value n
      #
      #
      c_diffs.each do |item|
        #line number
        l_number = item[0][1]
        #how it is
        modified_ = item[0][2][0].to_s.clone
        modified_line = modified_.to_s.clone

        if !item[1].nil?
          #original line
          original_ = item[1][2][0].to_s.clone
          masked_line = original_.to_s.clone
        else
          original_ = ""
          masked_line = original_.to_s.clone
        end

        for i in (0..modified_line.size) do
          #if the modified line is bigger then the original fill the extra chars with a minus signal, indicating they should be removed
          if i >= masked_line.size
            masked_line += '-'
            #if the char is the same change it to dot, indicating that position is ok
          elsif modified_line[i] == masked_line[i]
            masked_line[i] = '.'
          end
          #if character is different keep the original character, indicating that one should be used instead
        end
        mask = masked_line
        printable.push([l_number, modified_, original_, mask,])
      end
      printable
    end

    attr_reader :diffs, :difftype

    def initialize(diffs_or_a, b = nil, isstring = nil)
      if b.nil?
        @diffs = diffs_or_a
        @isstring = isstring
      else
        @diffs = []
        @curdiffs = []
        makediff(diffs_or_a, b)
        @difftype = diffs_or_a.class
      end
    end

    def match(ai, bi)
      @diffs.push @curdiffs unless @curdiffs.empty?
      @curdiffs = []
    end

    def discarda(i, elem)
      @curdiffs.push ['-', i, elem]
    end

    def discardb(i, elem)
      @curdiffs.push ['+', i, elem]
    end

    def compact
      return Diff.new(compactdiffs)
    end

    def compact!
      @diffs = compactdiffs
    end

    def inspect
      @diffs.inspect
    end

  end


end
=begin
= Diff
(({diff.rb})) - computes the differences between two arrays or
strings. Copyright (C) 2001 Lars Christensen

== Synopsis

    diff = Diff.new(a, b)
    b = a.patch(diff)

== Class Diff
=== Class Methods
--- Diff.new(a, b)
--- a.diff(b)
      Creates a Diff object which represent the differences between
      ((|a|)) and ((|b|)). ((|a|)) and ((|b|)) can be either be arrays
      of any objects, strings, or object of any class that include
      module ((|Diffable|))

== Module Diffable
The module ((|Diffable|)) is intended to be included in any class for
which differences are to be computed. Diffable is included into String
and Array when (({diff.rb})) is (({require}))'d.

Classes including Diffable should implement (({[]})) to get element at
integer indices, (({<<})) to append elements to the object and
(({ClassName#new})) should accept 0 arguments to create a new empty
object.

=== Instance Methods
--- Diffable#patch(diff)
      Applies the differences from ((|diff|)) to the object ((|obj|))
      and return the result. ((|obj|)) is not changed. ((|obj|)) and
      can be either an array or a string, but must match the object
      from which the ((|diff|)) was created.
=end
